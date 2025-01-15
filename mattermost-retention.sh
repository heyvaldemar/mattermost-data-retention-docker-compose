#!/bin/bash

# Database drive (replace with yours)
# (postgres / mysql)
DB_DRIVE="postgres"

# Database name (replace with yours)
DB_NAME="mattermostdb"

# Database user (replace with yours)
DB_USER="mattermostdbuser"

# Database password (replace with yours)
DB_PASS="AkhQneTBFxpgvUrtDaKswXG"

# Database hostname (replace with yours)
DB_HOST="postgres"

# Mattermost hostname (replace with yours)
MATTERMOST_HOST="mattermost"

# Amount of days to keep messages and files (replace with yours)
RETENTION="1"

# Mattermost data directory
DATA_PATH="/mattermost/data/"

# Determine the PostgreSQL and Mattermost container IDs based on their images
POSTGRES_CONTAINER_ID=$(docker ps --format '{{.ID}}\t{{.Image}}' | grep 'postgres:' | awk '{print $1}')
MATTERMOST_CONTAINER_ID=$(docker ps --format '{{.ID}}\t{{.Image}}' | grep 'mattermost/mattermost-team-edition:' | awk '{print $1}')

# Check if the containers are running
if [ -z "$POSTGRES_CONTAINER_ID" ]; then
    echo "Postgres container not running!"
    exit 1
fi

if [ -z "$MATTERMOST_CONTAINER_ID" ]; then
    echo "Mattermost container not running!"
    exit 1
fi

# Set the docker command prefix for accessing DB and Mattermost
DB_DOCKER_CMD="docker exec -e PGPASSWORD=$DB_PASS $POSTGRES_CONTAINER_ID"
MM_DOCKER_CMD="docker exec $MATTERMOST_CONTAINER_ID"

# Get the script name
SCRIPT_NAME=$(basename "$0")

# Get the script full path
SCRIPT_PATH=$(readlink -f "$0")

# Get the script directory
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")

# Define log file path
LOG_FILE_PATH="$SCRIPT_DIR/$(basename "$0" .sh).log"

# Replace the cron job
(crontab -l 2>/dev/null | sed "/$SCRIPT_NAME/d"; echo "0 8 * * * /bin/bash $SCRIPT_PATH >> $LOG_FILE_PATH 2>&1") | crontab -

# Сalculate epoch in milisec
delete_before=$(date  --date="$RETENTION day ago"  "+%s%3N")
echo $(date  --date="$RETENTION day ago")

case $DB_DRIVE in

  postgres)
        echo "Using postgres database."
        export PGPASSWORD=$DB_PASS

        # Get list of files to be removed
        $DB_DOCKER_CMD psql -h "$DB_HOST" -U"$DB_USER" "$DB_NAME" -t -c "select path from fileinfo where createat < $delete_before;" > /tmp/mattermost-paths.list
        $DB_DOCKER_CMD psql -h "$DB_HOST" -U"$DB_USER" "$DB_NAME" -t -c "select thumbnailpath from fileinfo where createat < $delete_before;" >> /tmp/mattermost-paths.list
        $DB_DOCKER_CMD psql -h "$DB_HOST" -U"$DB_USER" "$DB_NAME" -t -c "select previewpath from fileinfo where createat < $delete_before;" >> /tmp/mattermost-paths.list

        # Cleanup db
        $DB_DOCKER_CMD psql -h "$DB_HOST" -U"$DB_USER" "$DB_NAME" -t -c "delete from posts where createat < $delete_before;"
        $DB_DOCKER_CMD psql -h "$DB_HOST" -U"$DB_USER" "$DB_NAME" -t -c "delete from fileinfo where createat < $delete_before;"
    ;;

  mysql)
        echo "Using mysql database."

        # Get list of files to be removed
        $DB_DOCKER_CMD mysql --password=$DB_PASS --user=$DB_USER --host=$DB_HOST --database=$DB_NAME --execute="select path from FileInfo where createat < $delete_before;" > /tmp/mattermost-paths.list
        $DB_DOCKER_CMD mysql --password=$DB_PASS --user=$DB_USER --host=$DB_HOST --database=$DB_NAME --execute="select thumbnailpath from FileInfo where createat < $delete_before;" >> /tmp/mattermost-paths.list
        $DB_DOCKER_CMD mysql --password=$DB_PASS --user=$DB_USER --host=$DB_HOST --database=$DB_NAME --execute="select previewpath from FileInfo where createat < $delete_before;" >> /tmp/mattermost-paths.list

        # Cleanup db
        $DB_DOCKER_CMD mysql --password=$DB_PASS --user=$DB_USER --host=$DB_HOST --database=$DB_NAME --execute="delete from Posts where createat < $delete_before;"
        $DB_DOCKER_CMD mysql --password=$DB_PASS --user=$DB_USER --host=$DB_HOST --database=$DB_NAME --execute="delete from FileInfo where createat < $delete_before;"
    ;;
  *)
        echo "Unknown DB_DRIVE option. Currently ONLY mysql AND postgres are available."
        exit 1
    ;;
esac

# Delete files
for fp in `cat /tmp/mattermost-paths.list`
do
        if [ -n "$fp" ]; then
                echo "$DATA_PATH""$fp"
                $MM_DOCKER_CMD shred -u "$DATA_PATH""$fp"
        fi
done

# Cleanup after script execution
rm /tmp/mattermost-paths.list

# Cleanup empty data dirs
$MM_DOCKER_CMD find $DATA_PATH -type d -empty -delete
exit 0
