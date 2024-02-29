#!/bin/bash

# Mattermost Data Retention Using Docker Compose

# The `mattermost-retention.sh` script assists in managing and cleaning up your Mattermost server to retain only a specific number of days' worth of messages and files.

# The steps performed by the script include:
# 1. **Environment Setup**: The script sets up the essential environment variables required for database connections, such as database name, user, password, host, and other related configurations like the Mattermost hostname, retention days, and Mattermost data directory.
# 2. **Container Identification**: Based on the Docker images used by the PostgreSQL and Mattermost services, the script identifies the running containers' IDs. This makes the script flexible, not relying on fixed container names.
# 3. **Cron Job Management**: For automation, the script first removes any existing cron jobs related to itself and then schedules a new one to run at 8 AM UTC daily.
# 4. **Retention Time Calculation**: The script computes the timestamp that corresponds to the specified retention days in the past.
# 5. **Database Interactions**: Depending on whether you're using PostgreSQL or MySQL (based on your configuration), the script communicates with the database running inside a Docker container to:
#     * Fetch file paths of files created before the retention date and save these paths in a temporary file.
#     * Delete posts and file information that were created before the retention date.
# 6. **File Deletion**: The script accesses the file paths from the temporary file and erases each one from the Mattermost server running within a Docker container.
# 7. **Cleanup**: The script gets rid of the temporary file and removes any empty directories in the Mattermost data path.
# By executing these steps, the script ensures that the Mattermost server retains only messages and files from the specified retention days, allowing you to manage storage more efficiently.

# ## Running the Script
# Before executing the script, update the environment variables at the beginning of the `mattermost-retention.sh` to match your configuration.

# To make the script executable, modify its permissions using:
# ```
# chmod +x mattermost-retention.sh
# ```

# After this, you can run the script with:
# ```
# ./mattermost-retention.sh
# ```

# ## Viewing Logs
# After adding `mattermost-retention.sh` to the crontab and it has executed, you can check the logs to verify if it operated successfully or if there were any issues.
# You can find the logs for `mattermost-retention.sh` in the directory from which you initiated the script.

# Author
# I’m Vladimir Mikhalev, the Docker Captain, but my friends can call me Valdemar.
# https://www.docker.com/captains/vladimir-mikhalev/

# My website with detailed IT guides: https://www.heyvaldemar.com/
# Follow me on YouTube: https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1
# Follow me on Twitter: https://twitter.com/heyValdemar
# Follow me on Instagram: https://www.instagram.com/heyvaldemar/
# Follow me on Mastodon: https://mastodon.social/@heyvaldemar
# Follow me on Bluesky: https://bsky.app/profile/heyvaldemar.bsky.social
# Follow me on Facebook: https://www.facebook.com/heyValdemarFB/
# Follow me on TikTok: https://www.tiktok.com/@heyvaldemar
# Follow me on LinkedIn: https://www.linkedin.com/in/heyvaldemar/
# Follow me on GitHub: https://github.com/heyvaldemar

# Communication
# Chat with IT pros on Discord: https://discord.gg/AJQGCCBcqf
# Reach me at ask@sre.gg

# Give Thanks
# Support on GitHub: https://github.com/sponsors/heyValdemar
# Support on Patreon: https://www.patreon.com/heyValdemar
# Support on BuyMeaCoffee: https://www.buymeacoffee.com/heyValdemar
# Support on Ko-fi: https://ko-fi.com/heyValdemar
# Support on PayPal: https://www.paypal.com/paypalme/heyValdemarCOM

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
