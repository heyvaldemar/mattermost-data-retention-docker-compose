#!/bin/bash

# Mattermost Data Retention Using Docker Compose

# The `mattermost-retention.sh` script is a management and cleanup script used to retain only a specific number of days of messages and files for a Mattermost server. The main tasks performed by the script are as follows:

# 1. Environment Setup: It establishes the necessary environment variables for database connection details, Mattermost hostname, retention days, Mattermost data directory path, and Docker Compose file path.

# 2. Cron Job Replacement: The script first removes any existing cron jobs that involve itself and then creates a new one scheduled to run at 8 AM UTC daily.

# 3. Retention Time Calculation: It calculates the timestamp corresponding to the retention days specified in the past.

# 4. Database Operations: The script interacts with the database (either PostgreSQL or MySQL, based on the configuration) running inside a Docker container.
#    The operations include:
#     * Retrieving the paths of files that were created before the retention date and storing these paths in a temporary file.
#     * Deleting posts and file information from the database that were created before the retention date.
#     * File Deletion: The script reads the file paths stored in the temporary file and deletes each file from the Mattermost server running inside a Docker container.

# 5. Directory Cleanup: The script removes the temporary file used for storing file paths and deletes any empty directories in the Mattermost data directory.

# By performing these tasks, the script ensures that only the specified number of days of messages and files are retained on the Mattermost server, helping manage the storage used by Mattermost more effectively.

# # Run the Script
# You need to replace the environment variables at the top of the script `mattermost-retention.sh` to meet your requirements.

# Before you can run the script, you need to make it executable. Use the chmod command to update the script's permissions:
# `chmod +x mattermost-retention.sh`

# Once the script is executable, you can run it:
# `./mattermost-retention.sh`

# # mattermost-retention.sh Logs
# Once the `mattermost-retention.sh` has been added to crontab and has run, you can check its logs to confirm whether it ran successfully or encountered any errors.
# The logs for `mattermost-retention.sh` can always be found in the same folder where you run the script.

# Author
# I’m Vladimir Mikhalev, the Docker Captain, but my friends can call me Valdemar.
# https://www.docker.com/captains/vladimir-mikhalev/

# My website with detailed IT guides: https://www.heyvaldemar.com/
# Follow me on YouTube: https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1
# Follow me on Twitter: https://twitter.com/heyValdemar
# Follow me on Instagram: https://www.instagram.com/heyvaldemar/
# Follow me on Mastodon: https://hachyderm.io/@heyValdemar
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
DB_PASS="zkhuneTBFxpgvUrtDaKs9XG"

# Database hostname (replace with yours)
DB_HOST="postgres"

# Mattermost hostname (replace with yours)
MATTERMOST_HOST="mattermost"

# Amount of days to keep messages and files (replace with yours)
RETENTION="1"

# Mattermost data directory
DATA_PATH="/mattermost/data/"

# Path to Docker Compose file (replace with yours)
DOCKER_COMPOSE_FILE="/home/ubuntu/mattermost/mattermost-traefik-letsencrypt-docker-compose.yml"

# Set the docker command prefix for accessing DB
DB_DOCKER_CMD="docker compose -f $DOCKER_COMPOSE_FILE exec -e PGPASSWORD=$DB_PASS $DB_HOST"

# Set the docker command prefix for accessing Mattermost
MM_DOCKER_CMD="docker compose -f $DOCKER_COMPOSE_FILE exec $MATTERMOST_HOST"

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
