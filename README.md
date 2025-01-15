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

## Author

hey everyone,

💾 I’ve been in the IT game for over 20 years, cutting my teeth with some big names like [IBM](https://www.linkedin.com/in/heyvaldemar/), [Thales](https://www.linkedin.com/in/heyvaldemar/), and [Amazon](https://www.linkedin.com/in/heyvaldemar/). These days, I wear the hat of a DevOps Consultant and Team Lead, but what really gets me going is Docker and container technology - I’m kind of obsessed!

💛 I have my own IT [blog](https://www.heyvaldemar.com/), where I’ve built a [community](https://discord.gg/AJQGCCBcqf) of DevOps enthusiasts who share my love for all things Docker, containers, and IT technologies in general. And to make sure everyone can jump on this awesome DevOps train, I write super detailed guides (seriously, they’re foolproof!) that help even newbies deploy and manage complex IT solutions.

🚀 My dream is to empower every single person in the DevOps community to squeeze every last drop of potential out of Docker and container tech.

🐳 As a [Docker Captain](https://www.docker.com/captains/vladimir-mikhalev/), I’m stoked to share my knowledge, experiences, and a good dose of passion for the tech. My aim is to encourage learning, innovation, and growth, and to inspire the next generation of IT whizz-kids to push Docker and container tech to its limits.

Let’s do this together!

## My 2D Portfolio

🕹️ Click into [sre.gg](https://www.sre.gg/) — my virtual space is a 2D pixel-art portfolio inviting you to interact with elements that encapsulate the milestones of my DevOps career.

## My Courses

🎓 Dive into my [comprehensive IT courses](https://www.heyvaldemar.com/courses/) designed for enthusiasts and professionals alike. Whether you're looking to master Docker, conquer Kubernetes, or advance your DevOps skills, my courses provide a structured pathway to enhancing your technical prowess.

🔑 [Each course](https://www.udemy.com/user/heyvaldemar/) is built from the ground up with real-world scenarios in mind, ensuring that you gain practical knowledge and hands-on experience. From beginners to seasoned professionals, there's something here for everyone to elevate their IT skills.

## My Services

💼 Take a look at my [service catalog](https://www.heyvaldemar.com/services/) and find out how we can make your technological life better. Whether it's increasing the efficiency of your IT infrastructure, advancing your career, or expanding your technological horizons — I'm here to help you achieve your goals. From DevOps transformations to building gaming computers — let's make your technology unparalleled!

## Patreon Exclusives

🏆 Join my [Patreon](https://www.patreon.com/heyvaldemar) and dive deep into the world of Docker and DevOps with exclusive content tailored for IT enthusiasts and professionals. As your experienced guide, I offer a range of membership tiers designed to suit everyone from newbies to IT experts.

## My Recommendations

📕 Check out my collection of [essential DevOps books](https://kit.co/heyvaldemar/essential-devops-books)\
🖥️ Check out my [studio streaming and recording kit](https://kit.co/heyvaldemar/my-studio-streaming-and-recording-kit)\
📡 Check out my [streaming starter kit](https://kit.co/heyvaldemar/streaming-starter-kit)

## Follow Me

🎬 [YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1)\
🐦 [X / Twitter](https://twitter.com/heyvaldemar)\
🎨 [Instagram](https://www.instagram.com/heyvaldemar/)\
🐘 [Mastodon](https://mastodon.social/@heyvaldemar)\
🧵 [Threads](https://www.threads.net/@heyvaldemar)\
🎸 [Facebook](https://www.facebook.com/heyvaldemarFB/)\
🧊 [Bluesky](https://bsky.app/profile/heyvaldemar.bsky.social)\
🎥 [TikTok](https://www.tiktok.com/@heyvaldemar)\
💻 [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)\
📣 [daily.dev Squad](https://app.daily.dev/squads/devopscompass)\
🧩 [LeetCode](https://leetcode.com/u/heyvaldemar/)\
🐈 [GitHub](https://github.com/heyvaldemar)

## Community of IT Experts

👾 [Discord](https://discord.gg/AJQGCCBcqf)

## Refill My Coffee Supplies

💖 [PayPal](https://www.paypal.com/paypalme/heyvaldemarCOM)\
🏆 [Patreon](https://www.patreon.com/heyvaldemar)\
💎 [GitHub](https://github.com/sponsors/heyvaldemar)\
🥤 [BuyMeaCoffee](https://www.buymeacoffee.com/heyvaldemar)\
🍪 [Ko-fi](https://ko-fi.com/heyvaldemar)

🌟 **Bitcoin (BTC):** bc1q2fq0k2lvdythdrj4ep20metjwnjuf7wccpckxc\
🔹 **Ethereum (ETH):** 0x76C936F9366Fad39769CA5285b0Af1d975adacB8\
🪙 **Binance Coin (BNB):** bnb1xnn6gg63lr2dgufngfr0lkq39kz8qltjt2v2g6\
💠 **Litecoin (LTC):** LMGrhx8Jsx73h1pWY9FE8GB46nBytjvz8g

<div align="center">

### Show some 💜 by starring some of the [repositories](https://github.com/heyValdemar?tab=repositories)!

![octocat](https://user-images.githubusercontent.com/10498744/210113490-e2fad07f-4488-4da8-a656-b9abbdd8cb26.gif)

</div>

![footer](https://user-images.githubusercontent.com/10498744/210157572-1fca0242-8af2-46a6-bfa3-666ffd40ebde.svg)
