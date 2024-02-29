# Mattermost Data Retention Using Docker Compose

The `mattermost-retention.sh` script assists in managing and cleaning up your Mattermost server to retain only a specific number of days' worth of messages and files. The steps performed by the script include:

1. **Environment Setup**: The script sets up the essential environment variables required for database connections, such as database name, user, password, host, and other related configurations like the Mattermost hostname, retention days, and Mattermost data directory.

2. **Container Identification**: Based on the Docker images used by the PostgreSQL and Mattermost services, the script identifies the running containers' IDs. This makes the script flexible, not relying on fixed container names.

3. **Cron Job Management**: For automation, the script first removes any existing cron jobs related to itself and then schedules a new one to run at 8 AM UTC daily.

4. **Retention Time Calculation**: The script computes the timestamp that corresponds to the specified retention days in the past.

5. **Database Interactions**: Depending on whether you're using PostgreSQL or MySQL (based on your configuration), the script communicates with the database running inside a Docker container to:
    * Fetch file paths of files created before the retention date and save these paths in a temporary file.
    * Delete posts and file information that were created before the retention date.

6. **File Deletion**: The script accesses the file paths from the temporary file and erases each one from the Mattermost server running within a Docker container.

7. **Cleanup**: The script gets rid of the temporary file and removes any empty directories in the Mattermost data path.

By executing these steps, the script ensures that the Mattermost server retains only messages and files from the specified retention days, allowing you to manage storage more efficiently.

## Running the Script

Before executing the script, update the environment variables at the beginning of the `mattermost-retention.sh` to match your configuration.

To make the script executable, modify its permissions using:

```
chmod +x mattermost-retention.sh
```

After this, you can run the script with:

```
./mattermost-retention.sh
```

## Viewing Logs

After adding `mattermost-retention.sh` to the crontab and it has executed, you can check the logs to verify if it operated successfully or if there were any issues.

You can find the logs for `mattermost-retention.sh` in the directory from which you initiated the script.


# Author

I’m Vladimir Mikhalev, the [Docker Captain](https://www.docker.com/captains/vladimir-mikhalev/), but my friends can call me Valdemar.

🌐 My [website](https://www.heyvaldemar.com/) with detailed IT guides\
🎬 Follow me on [YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1)\
🐦 Follow me on [Twitter](https://twitter.com/heyValdemar)\
🎨 Follow me on [Instagram](https://www.instagram.com/heyvaldemar/)\
🐘 Follow me on [Mastodon](https://mastodon.social/@heyvaldemar)\
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
