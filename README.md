# Mattermost Data Retention Using Docker Compose

The `mattermost-retention.sh` script is a management and cleanup script used to retain only a specific number of days of messages and files for a Mattermost server. The main tasks performed by the script are as follows:

1. **Environment Setup**: It establishes the necessary environment variables for database connection details, Mattermost hostname, retention days, Mattermost data directory path, and Docker Compose file path.

2. **Cron Job Replacement**: The script first removes any existing cron jobs that involve itself and then creates a new one scheduled to run at 8 AM UTC daily.

3. **Retention Time Calculation**: It calculates the timestamp corresponding to the retention days specified in the past.

4. **Database Operations**: The script interacts with the database (either PostgreSQL or MySQL, based on the configuration) running inside a Docker container.

   The operations include:
    * Retrieving the paths of files that were created before the retention date and storing these paths in a temporary file.
    * Deleting posts and file information from the database that were created before the retention date.
    * File Deletion: The script reads the file paths stored in the temporary file and deletes each file from the Mattermost server running inside a Docker container.

5. **Directory Cleanup**: The script removes the temporary file used for storing file paths and deletes any empty directories in the Mattermost data directory.

By performing these tasks, the script ensures that only the specified number of days of messages and files are retained on the Mattermost server, helping manage the storage used by Mattermost more effectively.

# Run the Script

You need to replace the environment variables at the top of the script `mattermost-retention.sh` to meet your requirements.

Before you can run the script, you need to make it executable. Use the chmod command to update the script's permissions:

`chmod +x mattermost-retention.sh`

Once the script is executable, you can run it:

`./mattermost-retention.sh`

# mattermost-retention.sh Logs

Once the `mattermost-retention.sh` has been added to crontab and has run, you can check its logs to confirm whether it ran successfully or encountered any errors.

The logs for `mattermost-retention.sh` can always be found in the same folder where you run the script.

# Author

I’m Vladimir Mikhalev, the [Docker Captain](https://www.docker.com/captains/vladimir-mikhalev/), but my friends can call me Valdemar.

🌐 My [website](https://www.heyvaldemar.com/) with detailed IT guides\
🎬 Follow me on [YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1)\
🐦 Follow me on [Twitter](https://twitter.com/heyValdemar)\
🎨 Follow me on [Instagram](https://www.instagram.com/heyvaldemar/)\
🐘 Follow me on [Mastodon](https://hachyderm.io/@heyValdemar)\
🧊 Follow me on [Bluesky](https://bsky.app/profile/heyvaldemar.bsky.social)\
🎸 Follow me on [Facebook](https://www.facebook.com/heyValdemarFB/)\
🎥 Follow me on [TikTok](https://www.tiktok.com/@heyvaldemar)\
💻 Follow me on [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)\
🐈 Follow me on [GitHub](https://github.com/heyvaldemar)

# Communication

👾 Chat with IT pros on [Discord](https://discord.gg/AJQGCCBcqf)\
📧 Reach me at ask@sre.gg

# Give Thanks

💎 Support on [GitHub](https://github.com/sponsors/heyValdemar)\
🏆 Support on [Patreon](https://www.patreon.com/heyValdemar)\
🥤 Support on [BuyMeaCoffee](https://www.buymeacoffee.com/heyValdemar)\
🍪 Support on [Ko-fi](https://ko-fi.com/heyValdemar)\
💖 Support on [PayPal](https://www.paypal.com/paypalme/heyValdemarCOM)
