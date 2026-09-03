# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.0.0] - 2026-09-01

### Fixed (the script did not work against current Mattermost images)

- **File deletion moved to a helper container.** Current
  `mattermost/mattermost-team-edition` images are distroless, no shell,
  no `shred`, no `find`, so every `docker exec` file operation in the
  old script failed. Expired rows were deleted from the database while
  the files stayed on disk forever. Cleanup now runs in a throwaway
  `debian:stable-slim` container sharing the Mattermost container's
  volumes.
- **Portable cutoff computation** (`date +%s` arithmetic instead of the
  GNU-only `date --date`), with a numeric sanity check before any SQL
  runs.
- Filenames with spaces survive the deletion loop; the temporary paths
  list is a `mktemp` file cleaned up on exit; empty-directory pruning
  no longer risks removing the data root.

### Security

- **The database password is no longer hardcoded in the tracked script.**
  Configuration comes from environment variables or a gitignored
  `mattermost-retention.conf`. Rotate the previously tracked password if
  your deployment reused it.

### Added

- Cron installation can be disabled (`INSTALL_CRON=false`).
- **Retention Script Verification workflow**: shellcheck + actionlint,
  plus an integration test against a real PostgreSQL and a seeded data
  volume that asserts expired data is removed and current data survives.

[Unreleased]: https://github.com/heyvaldemar/mattermost-data-retention-docker-compose/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/heyvaldemar/mattermost-data-retention-docker-compose/releases/tag/v1.0.0
