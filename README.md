# Mattermost Data Retention

[![Retention Script Verification](https://github.com/heyvaldemar/mattermost-data-retention-docker-compose/actions/workflows/retention-verification.yml/badge.svg?branch=main)](https://github.com/heyvaldemar/mattermost-data-retention-docker-compose/actions/workflows/retention-verification.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

`mattermost-retention.sh` keeps a dockerized Mattermost server down to a fixed number of days of history: it deletes older posts from the database, shreds the matching uploaded files, and prunes empty data directories. Team Edition has no built-in data retention (that's an Enterprise feature). This script is the self-hosted answer.

Works with the [mattermost-traefik-letsencrypt-docker-compose](https://github.com/heyvaldemar/mattermost-traefik-letsencrypt-docker-compose) template out of the box, and with any Docker deployment using the official `mattermost/*` images and a `postgres:`/`mysql:` database container.

## How it works

1. Finds the database and Mattermost containers by image name, no fixed container names required.
2. Computes the cutoff (`RETENTION` days ago) and collects the file paths of expired uploads from the database.
3. Deletes expired rows from `posts` and `fileinfo`.
4. Shreds the expired files and prunes empty directories via a throwaway helper container that shares the Mattermost container's volumes: current Mattermost images are distroless (no shell inside), so `docker exec` file cleanup stopped being possible.
5. Re-installs its own daily cron entry (08:00) unless `INSTALL_CRON=false`.

## Usage

```bash
git clone https://github.com/heyvaldemar/mattermost-data-retention-docker-compose
cd mattermost-data-retention-docker-compose
chmod +x mattermost-retention.sh

# Configuration lives in a gitignored file next to the script —
# the database password never goes into the script or the repo.
cat > mattermost-retention.conf <<'EOF'
DB_PASS="your_database_password"
RETENTION="30"
EOF

./mattermost-retention.sh
```

All settings and their defaults:

| Variable | Default | Meaning |
|---|---|---|
| `DB_DRIVE` | `postgres` | `postgres` or `mysql` |
| `DB_NAME` | `mattermostdb` | database name |
| `DB_USER` | `mattermostdbuser` | database user |
| `DB_PASS` | - (required) | database password |
| `DB_HOST` | `postgres` | database host as the DB container sees it |
| `RETENTION` | `30` | days of history to keep |
| `DATA_PATH` | `/mattermost/data/` | data directory inside the Mattermost container |
| `INSTALL_CRON` | `true` | maintain the daily 08:00 cron entry |
| `HELPER_IMAGE` | `debian:stable-slim` | image used for the file-deletion helper |

Environment variables override the config file: `RETENTION=7 ./mattermost-retention.sh`.

## Viewing logs

The cron entry appends to `mattermost-retention.log` next to the script:

```bash
tail -f mattermost-retention.log
```

## Testing

The [Retention Script Verification](https://github.com/heyvaldemar/mattermost-data-retention-docker-compose/actions/workflows/retention-verification.yml?query=branch%3Amain) workflow runs on every push, pull request, and weekly: shellcheck + actionlint, then an integration test that boots a real PostgreSQL with Mattermost-shaped tables, seeds posts and files on both sides of the cutoff, runs the script, and asserts that expired data is gone while current data survives.

## Security notes

- **The database password lives in `mattermost-retention.conf` (gitignored) or the environment, never in the script.** Releases before v1.0.0 (2026-09-01) shipped the script with a generated-looking password hardcoded; rotate it if your deployment reused it.
- Files are removed with `shred -u`, so expired uploads are unrecoverable: that is the point of a retention policy. Test your `RETENTION` value against a backup first.

---

## About the maintainer

<div align="center">

**Maintained by [Vladimir Mikhalev](https://github.com/heyvaldemar)** — Docker Captain · IBM Champion · AWS Community Builder

[YouTube](https://www.youtube.com/channel/UCf85kQ0u1sYTTTyKVpxrlyQ?sub_confirmation=1) · [Blog](https://heyvaldemar.com) · [LinkedIn](https://www.linkedin.com/in/heyvaldemar/)

</div>
