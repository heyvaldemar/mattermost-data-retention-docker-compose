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
#
# The script discovers the containers by image name, so it does not depend
# on fixed container names. File deletion runs in a throwaway helper
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
: "${DB_PASS:?Set DB_PASS in the environment or in mattermost-retention.conf (never commit it)}"

# Determine the PostgreSQL/MySQL and Mattermost container IDs by image
POSTGRES_CONTAINER_ID=$(docker ps --format '{{.ID}}\t{{.Image}}' | grep -E 'postgres:|mysql:' | awk '{print $1}' | head -1)
MATTERMOST_CONTAINER_ID=$(docker ps --format '{{.ID}}\t{{.Image}}' | grep 'mattermost/mattermost' | awk '{print $1}' | head -1)

if [ -z "$POSTGRES_CONTAINER_ID" ]; then
    echo "Database container not running!"
    exit 1
fi

if [ -z "$MATTERMOST_CONTAINER_ID" ]; then
    echo "Mattermost container not running!"
    exit 1
fi

DB_DOCKER_CMD="docker exec -e PGPASSWORD=$DB_PASS $POSTGRES_CONTAINER_ID"

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
        $DB_DOCKER_CMD mysql --password="$DB_PASS" --user="$DB_USER" --host="$DB_HOST" --database="$DB_NAME" --execute="select path from FileInfo where createat < $delete_before;" > "$PATHS_LIST"
        $DB_DOCKER_CMD mysql --password="$DB_PASS" --user="$DB_USER" --host="$DB_HOST" --database="$DB_NAME" --execute="select thumbnailpath from FileInfo where createat < $delete_before;" >> "$PATHS_LIST"
        $DB_DOCKER_CMD mysql --password="$DB_PASS" --user="$DB_USER" --host="$DB_HOST" --database="$DB_NAME" --execute="select previewpath from FileInfo where createat < $delete_before;" >> "$PATHS_LIST"

        # Cleanup db
        $DB_DOCKER_CMD mysql --password="$DB_PASS" --user="$DB_USER" --host="$DB_HOST" --database="$DB_NAME" --execute="delete from Posts where createat < $delete_before;"
        $DB_DOCKER_CMD mysql --password="$DB_PASS" --user="$DB_USER" --host="$DB_HOST" --database="$DB_NAME" --execute="delete from FileInfo where createat < $delete_before;"
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
