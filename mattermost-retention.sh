#!/bin/bash

# Mattermost data retention: deletes posts and uploaded files older than
# RETENTION days from a dockerized Mattermost + PostgreSQL/MySQL setup.
#
# Configuration comes from environment variables, with optional overrides in
# a mattermost-retention.conf file next to this script (gitignored — that is
# where the database password belongs, never in the script itself):
#
#   DB_DRIVE="postgres"            # postgres / mysql
#   DB_NAME="mattermostdb"
#   DB_USER="mattermostdbuser"
#   DB_PASS="..."                  # REQUIRED
#   DB_HOST="postgres"
#   RETENTION="30"                 # days of history to keep
#   DATA_PATH="/mattermost/data/"
#   INSTALL_CRON="true"            # re-install the daily 08:00 cron entry
#   HELPER_IMAGE="debian:stable-slim"  # used for file deletion (see below)
#   COMPOSE_PROJECT=""             # compose project; empty = the one Mattermost runs in
#   MATTERMOST_SERVICE="mattermost"  # compose service of the Mattermost server
#   DB_SERVICE=""                  # compose service of the database; empty = DB_DRIVE
#   DB_CONTAINER=""                # name or id; overrides discovery
#   MATTERMOST_CONTAINER=""        # name or id; overrides discovery
#
# The containers are found by the labels Docker Compose puts on them: the
# Mattermost service, and the database service IN THE SAME PROJECT. With
# COMPOSE_PROJECT empty, the project is the one the Mattermost service runs
# in, and the script refuses when that is more than one project rather than
# guess. It used to match `docker ps` image names and take the first hit,
# which on a host with more than one stack could be another stack's database,
# or the template's own backups container (also a postgres image), and which
# found nothing once a digest-pinned tag had moved on the host and `docker ps`
# showed an image id instead of a name. File deletion runs in a throwaway helper
# container sharing the Mattermost container's volumes: current
# mattermost/mattermost-team-edition images are distroless (no shell, no
# shred), so exec'ing into them stopped being possible.

set -uo pipefail

SCRIPT_PATH=$(readlink -f "$0")
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
SCRIPT_NAME=$(basename "$0")

# Optional config file for secrets and overrides (gitignored).
if [ -f "$SCRIPT_DIR/mattermost-retention.conf" ]; then
    # shellcheck source=/dev/null
    . "$SCRIPT_DIR/mattermost-retention.conf"
fi

DB_DRIVE="${DB_DRIVE:-postgres}"
DB_NAME="${DB_NAME:-mattermostdb}"
DB_USER="${DB_USER:-mattermostdbuser}"
DB_HOST="${DB_HOST:-postgres}"
RETENTION="${RETENTION:-30}"
DATA_PATH="${DATA_PATH:-/mattermost/data/}"
INSTALL_CRON="${INSTALL_CRON:-true}"
HELPER_IMAGE="${HELPER_IMAGE:-debian:stable-slim}"
COMPOSE_PROJECT="${COMPOSE_PROJECT:-}"
MATTERMOST_SERVICE="${MATTERMOST_SERVICE:-mattermost}"
DB_SERVICE="${DB_SERVICE:-$DB_DRIVE}"
DB_CONTAINER="${DB_CONTAINER:-}"
MATTERMOST_CONTAINER="${MATTERMOST_CONTAINER:-}"
: "${DB_PASS:?Set DB_PASS in the environment or in mattermost-retention.conf (never commit it)}"

PROJECT_LABEL="com.docker.compose.project"
SERVICE_LABEL="com.docker.compose.service"
OVERRIDE_HINT="set COMPOSE_PROJECT, or name the containers with DB_CONTAINER and MATTERMOST_CONTAINER"

# Exactly one id from a list, or a refusal: none and more than one are both
# reasons to stop, never to pick.
only_one() {   # only_one <ids> <what> <where> <override variable>
    local n
    n="$(printf '%s' "$1" | grep -c . || true)"
    if [ "$n" -eq 1 ]; then
        printf '%s\n' "$1"
        return 0
    fi
    if [ "$n" -eq 0 ]; then
        echo "No running $2 container: $3; $OVERRIDE_HINT" >&2
    else
        echo "$n running containers could be the $2 container ($3), and this script will not guess: name it with $4" >&2
    fi
    return 1
}

# A compose service's one running container in a project.
service_container() {   # service_container <project> <service> <what> <override variable>
    only_one "$(docker ps -q --filter "label=$PROJECT_LABEL=$1" --filter "label=$SERVICE_LABEL=$2")" \
        "$3" "compose project '$1', service '$2'" "$4"
}

# Without compose, the one running container whose image matches. Kept for
# deployments started some other way; on a host where more than one container
# matches it refuses instead of taking the first.
image_container() {   # image_container <image ERE> <what> <override variable>
    only_one "$(docker ps --format '{{.ID}} {{.Image}}' | awk -v re="$1" '$2 ~ re { print $1 }')" \
        "$2" "no compose project runs Mattermost here, so it was looked for by image" "$3"
}

if [ -z "$COMPOSE_PROJECT" ]; then
    if [ -n "$MATTERMOST_CONTAINER" ]; then
        # The database belongs to the project of the Mattermost container named.
        COMPOSE_PROJECT="$(docker inspect --format "{{index .Config.Labels \"$PROJECT_LABEL\"}}" "$MATTERMOST_CONTAINER" 2>/dev/null || true)"
    else
        projects="$(docker ps --filter "label=$SERVICE_LABEL=$MATTERMOST_SERVICE" --format "{{.Label \"$PROJECT_LABEL\"}}" | sort -u | grep . || true)"
        if [ "$(printf '%s' "$projects" | grep -c . || true)" -gt 1 ]; then
            echo "Mattermost runs in more than one compose project on this host ($(printf '%s' "$projects" | paste -sd, - | sed 's/,/, /g')), and this script will not guess which one to delete from: set COMPOSE_PROJECT"
            exit 1
        fi
        COMPOSE_PROJECT="$projects"
    fi
fi

if [ -n "$MATTERMOST_CONTAINER" ]; then
    MATTERMOST_CONTAINER_ID="$MATTERMOST_CONTAINER"
elif [ -n "$COMPOSE_PROJECT" ]; then
    MATTERMOST_CONTAINER_ID="$(service_container "$COMPOSE_PROJECT" "$MATTERMOST_SERVICE" Mattermost MATTERMOST_CONTAINER)" || exit 1
else
    MATTERMOST_CONTAINER_ID="$(image_container '(^|/)mattermost/mattermost' Mattermost MATTERMOST_CONTAINER)" || exit 1
fi

if [ -n "$DB_CONTAINER" ]; then
    POSTGRES_CONTAINER_ID="$DB_CONTAINER"
elif [ -n "$COMPOSE_PROJECT" ]; then
    POSTGRES_CONTAINER_ID="$(service_container "$COMPOSE_PROJECT" "$DB_SERVICE" database DB_CONTAINER)" || exit 1
else
    POSTGRES_CONTAINER_ID="$(image_container '(^|/)(postgres|mysql)(:|@|$)' database DB_CONTAINER)" || exit 1
fi

echo "Mattermost container: $MATTERMOST_CONTAINER_ID, database container: $POSTGRES_CONTAINER_ID${COMPOSE_PROJECT:+ (compose project $COMPOSE_PROJECT)}"

# The password reaches docker by name and each client in its environment,
# never as an argument: every user on the host reads a process's arguments
# with ps, for as long as it runs. psql reads PGPASSWORD, mysql MYSQL_PWD.
export PGPASSWORD="$DB_PASS" MYSQL_PWD="$DB_PASS"
DB_DOCKER_CMD="docker exec -e PGPASSWORD -e MYSQL_PWD $POSTGRES_CONTAINER_ID"

LOG_FILE_PATH="$SCRIPT_DIR/$(basename "$0" .sh).log"

# Re-install the daily cron entry unless disabled
if [ "$INSTALL_CRON" = "true" ]; then
    (crontab -l 2>/dev/null | sed "/$SCRIPT_NAME/d"; echo "0 8 * * * /bin/bash $SCRIPT_PATH >> $LOG_FILE_PATH 2>&1") | crontab -
fi

# Calculate the cutoff epoch in milliseconds. Plain arithmetic on
# `date +%s` works on both GNU and BSD date (the previous GNU-only
# `--date` produced an empty cutoff on other platforms).
delete_before=$(( ($(date +%s) - RETENTION * 86400) * 1000 ))
case "$delete_before" in
    ''|*[!0-9]*) echo "Failed to compute the retention cutoff"; exit 1 ;;
esac
echo "Deleting posts and files created before: $(date -r $(( delete_before / 1000 )) 2>/dev/null || date -d "@$(( delete_before / 1000 ))")"

PATHS_LIST=$(mktemp /tmp/mattermost-paths.XXXXXX)
trap 'rm -f "$PATHS_LIST"' EXIT

case $DB_DRIVE in

  postgres)
        echo "Using postgres database."

        # Get the list of files to be removed
        $DB_DOCKER_CMD psql -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" -t -c "select path from fileinfo where createat < $delete_before;" > "$PATHS_LIST"
        $DB_DOCKER_CMD psql -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" -t -c "select thumbnailpath from fileinfo where createat < $delete_before;" >> "$PATHS_LIST"
        $DB_DOCKER_CMD psql -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" -t -c "select previewpath from fileinfo where createat < $delete_before;" >> "$PATHS_LIST"

        # Cleanup db
        $DB_DOCKER_CMD psql -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" -t -c "delete from posts where createat < $delete_before;"
        $DB_DOCKER_CMD psql -h "$DB_HOST" -U "$DB_USER" "$DB_NAME" -t -c "delete from fileinfo where createat < $delete_before;"
    ;;

  mysql)
        echo "Using mysql database."

        # Get the list of files to be removed
        $DB_DOCKER_CMD mysql --user="$DB_USER" --host="$DB_HOST" --database="$DB_NAME" --execute="select path from FileInfo where createat < $delete_before;" > "$PATHS_LIST"
        $DB_DOCKER_CMD mysql --user="$DB_USER" --host="$DB_HOST" --database="$DB_NAME" --execute="select thumbnailpath from FileInfo where createat < $delete_before;" >> "$PATHS_LIST"
        $DB_DOCKER_CMD mysql --user="$DB_USER" --host="$DB_HOST" --database="$DB_NAME" --execute="select previewpath from FileInfo where createat < $delete_before;" >> "$PATHS_LIST"

        # Cleanup db
        $DB_DOCKER_CMD mysql --user="$DB_USER" --host="$DB_HOST" --database="$DB_NAME" --execute="delete from Posts where createat < $delete_before;"
        $DB_DOCKER_CMD mysql --user="$DB_USER" --host="$DB_HOST" --database="$DB_NAME" --execute="delete from FileInfo where createat < $delete_before;"
    ;;
  *)
        echo "Unknown DB_DRIVE option. Currently ONLY mysql AND postgres are available."
        exit 1
    ;;
esac

# Delete files (shred so the content is unrecoverable, then unlink) and
# prune empty directories. Runs in one throwaway helper container that
# shares the Mattermost container's volumes — the mattermost images are
# distroless, so there is no shell inside them to exec.
docker run --rm -i --volumes-from "$MATTERMOST_CONTAINER_ID" \
        -e DATA_PATH="$DATA_PATH" "$HELPER_IMAGE" bash -c '
        while read -r fp; do
                fp="${fp#"${fp%%[![:space:]]*}"}"
                fp="${fp%"${fp##*[![:space:]]}"}"
                if [ -n "$fp" ] && [ -f "$DATA_PATH$fp" ]; then
                        echo "$DATA_PATH$fp"
                        shred -u "$DATA_PATH$fp"
                fi
        done
        find "$DATA_PATH" -mindepth 1 -type d -empty -delete
' < "$PATHS_LIST"
exit 0
