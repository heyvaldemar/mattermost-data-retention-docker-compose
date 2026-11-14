# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

_(no unreleased changes yet)_

## [1.2.0] - 2026-11-14

### Fixed

- **The script deletes from its own Mattermost, not from the first database
  on the host.** It found the database by taking the first `docker ps` line
  whose image looked like postgres or mysql. On a host with more than one
  stack that was whichever container started last, possibly another stack's
  database; in the template's own stack it could be the `backups` container,
  which runs the postgres image too; and once a digest-pinned tag had moved on
  the host, `docker ps` showed an image id instead of a name and nothing was
  found. Containers are now found by the labels Docker Compose puts on them:
  the `mattermost` service, and the database service of the same compose
  project. When Mattermost runs in more than one project the script refuses
  until `COMPOSE_PROJECT` names one, and a project without the service is
  refused, not guessed. Deployments without compose still work by image name,
  but only when a single container matches; with several it asks for
  `DB_CONTAINER` instead of taking the first.

### Added

- **`COMPOSE_PROJECT`, `MATTERMOST_SERVICE` and `DB_SERVICE`.** The project
  defaults to the one Mattermost runs in, the services to `mattermost` and to
  `DB_DRIVE`. `MATTERMOST_CONTAINER` alone now brings the database of its own
  compose project with it; `DB_CONTAINER` still overrides everything.
- **`tests/e2e-discovery.sh`** runs two compose projects of the same stack side
  by side and checks every run of the script against both: the project it was
  pointed at or found loses its expired data, the other keeps every row and
  file, and the ambiguous cases refuse and delete nothing.
  `tests/plants-discovery.tsv` puts five wrong discoveries back, the old one
  among them, and each has to fail it; `tests/plant-violations.py` takes
  `--plants` for that.

## [1.1.1] - 2026-11-08

### Security

- **The database password is no longer on any command line.** `mattermost-retention.sh` built `docker exec -e PGPASSWORD=<password>` (unquoted, too) and gave MySQL `--password=<password>`. Every user on the host reads a process's arguments with `ps`, and each `docker exec` stays up for as long as its statement runs, a long `DELETE` included. The script now exports `PGPASSWORD` and `MYSQL_PWD` and hands them to `docker exec` by name. `tests/e2e-retention.sh` holds `posts` locked so the script's `DELETE` waits, reads every command line on the machine and in the database container meanwhile, and requires none to carry the password (compared through a file, never printed); a new plant puts the old line back and the test has to notice.

## [1.1.0] - 2026-09-26

### Added

- **`DB_CONTAINER` and `MATTERMOST_CONTAINER`** name the containers to use. Discovery by image name took whichever PostgreSQL or MySQL container `docker ps` listed first, which on a host running more than one database is not necessarily Mattermost's. Empty keeps the discovery.
- **The end-to-end test runs anywhere Docker does, and is shown to fail.** `tests/e2e-retention.sh` is the CI test lifted out of the workflow, with a post and an upload 20 days old that a 30-day retention has to keep; `tests/plant-violations.py` breaks the script six ways on a copy and requires the test to notice each.

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

[Unreleased]: https://github.com/heyvaldemar/mattermost-data-retention-docker-compose/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/heyvaldemar/mattermost-data-retention-docker-compose/compare/v1.1.1...v1.2.0
[1.1.1]: https://github.com/heyvaldemar/mattermost-data-retention-docker-compose/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/heyvaldemar/mattermost-data-retention-docker-compose/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/heyvaldemar/mattermost-data-retention-docker-compose/releases/tag/v1.0.0
