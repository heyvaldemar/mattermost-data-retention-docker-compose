#!/bin/bash
# Two Mattermost stacks on one host, and the script deletes from its own.
#
# Discovery used to take the first `docker ps` line whose image looked like
# postgres or mysql. With two stacks that is whichever started last, and with
# the template's own backups container (also a postgres image) it could be
# that. Here two compose projects run the same stack side by side (tests/
# discovery-compose.yml), each holding a post and an upload 60 days old, and
# every run of the script is checked against BOTH: the project it was pointed
# at loses its expired data, the other keeps every row and every file.
#
# tests/plant-violations.py --plants tests/plants-discovery.tsv breaks the
# discovery on a copy and requires this to notice.
#
#   ./tests/e2e-discovery.sh        (needs Docker with the compose plugin)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
RUN="retention-disc-$$"
OURS="$RUN-ours"; THEIRS="$RUN-theirs"
COMPOSE_FILE="tests/discovery-compose.yml"
PASSED=0; FAILED=0
check() { if [ "$1" = yes ]; then echo "  PASS: $2"; PASSED=$((PASSED+1)); else echo "  FAIL: $3"; FAILED=$((FAILED+1)); fi; }
dc() { docker compose -p "$1" -f "$COMPOSE_FILE" "${@:2}"; }
cleanup() {
  for p in "$OURS" "$THEIRS"; do dc "$p" down -v --remove-orphans >/dev/null 2>&1; done
  docker rm -f "$RUN-plain" >/dev/null 2>&1; docker rmi "mattermost/mattermost-team-edition:$RUN" >/dev/null 2>&1
  rm -f "${OUT:-}"
}
trap cleanup EXIT

DB_PASS="$(openssl rand -hex 16)"
export POSTGRES_PASSWORD="$DB_PASS"
OUT="$(mktemp)"
# Ours first, theirs second: `docker ps` lists the newest first, so the old
# discovery would have taken a container of theirs.
for p in "$OURS" "$THEIRS"; do dc "$p" up -d --quiet-pull >/dev/null 2>&1 || { echo "  FAIL: $p did not start"; exit 1; }; done

# The test's own reads and writes go over the container's local socket, which
# needs no password; the script under test logs in over TCP with DB_PASS.
sql() { dc "$1" exec -T postgres psql -U mattermostdbuser mattermostdb -t -A -c "$2"; }
for p in "$OURS" "$THEIRS"; do
  for _ in $(seq 1 60); do sql "$p" 'select 1' >/dev/null 2>&1 && break; sleep 2; done
  sql "$p" "create table posts (id serial, createat bigint, message text);
    create table fileinfo (id serial, createat bigint, path text, thumbnailpath text, previewpath text);" >/dev/null
done
ms() { echo $(( ($(date +%s) - $1 * 86400) * 1000 )); }
seed() {   # every stack back to: an expired post and upload, and a current one
  for p in "$OURS" "$THEIRS"; do
    sql "$p" "truncate posts; truncate fileinfo;
      insert into posts (createat, message) values ($(ms 60), 'old post'), ($(ms 0), 'new post');
      insert into fileinfo (createat, path, thumbnailpath, previewpath) values
        ($(ms 60), 'old/expired.txt', '', ''), ($(ms 0), 'new/current.txt', '', '');" >/dev/null
    dc "$p" exec -T mattermost sh -c 'mkdir -p /mattermost/data/old /mattermost/data/new
      echo x > /mattermost/data/old/expired.txt; echo x > /mattermost/data/new/current.txt'
  done
}
# "cleaned" or "untouched", or what was found instead
state() {
  local posts expired current
  posts="$(sql "$1" 'select message from posts order by createat;' | tr '\n' ',')"
  expired="$(dc "$1" exec -T mattermost test -e /mattermost/data/old/expired.txt && echo on-disk || echo gone)"
  current="$(dc "$1" exec -T mattermost test -e /mattermost/data/new/current.txt && echo on-disk || echo gone)"
  case "$posts/$expired/$current" in
    "new post,/gone/on-disk") echo cleaned ;;
    "old post,new post,/on-disk/on-disk") echo untouched ;;
    *) echo "posts=$posts expired=$expired current=$current" ;;
  esac
}
retention() {   # retention [VAR=value ...]: the script, as cron would run it
  # DB_PASS reaches env through its environment, never as one of its arguments.
  DB_PASS="$DB_PASS" RETENTION=30 INSTALL_CRON=false HELPER_IMAGE=debian:stable-slim \
    env "$@" bash mattermost-retention.sh > "$OUT" 2>&1
}
said() { grep -qF -- "$1" "$OUT"; }
id_of() { dc "$1" ps -q "$2" | cut -c1-12; }   # the short id, as `docker ps -q` prints it

echo "== two Mattermost stacks, nothing named: the script refuses"
seed
retention; rc=$?
check "$([ "$rc" -ne 0 ] && echo yes || echo no)" "it exits non-zero" "it exited 0 with two stacks to choose from"
check "$(said "$OURS" && said "$THEIRS" && said COMPOSE_PROJECT && echo yes || echo no)" \
  "and names both projects and COMPOSE_PROJECT" "its message did not name both projects: $(head -c 300 "$OUT")"
check "$([ "$(state "$OURS")" = untouched ] && [ "$(state "$THEIRS")" = untouched ] && echo yes || echo no)" \
  "and neither stack lost a row or a file" "something was deleted: ours $(state "$OURS"), theirs $(state "$THEIRS")"

echo "== COMPOSE_PROJECT names ours"
seed
retention COMPOSE_PROJECT="$OURS"; rc=$?
check "$([ "$rc" -eq 0 ] && echo yes || echo no)" "the script completes" "the script exited $rc: $(tail -c 300 "$OUT")"
check "$([ "$(state "$OURS")" = cleaned ] && echo yes || echo no)" "ours lost its expired post and upload, and kept the current ones" "ours: $(state "$OURS")"
check "$([ "$(state "$THEIRS")" = untouched ] && echo yes || echo no)" "theirs kept every row and every file" "theirs: $(state "$THEIRS")"
check "$(said "database container: $(id_of "$OURS" postgres)" && echo yes || echo no)" \
  "the database it used is our postgres service, not the backups container on the same image" "it used another database container: $(grep -m1 'database container' "$OUT")"

echo "== MATTERMOST_CONTAINER names theirs: the database comes from the same project"
seed
retention MATTERMOST_CONTAINER="$(id_of "$THEIRS" mattermost)"; rc=$?
check "$([ "$rc" -eq 0 ] && [ "$(state "$THEIRS")" = cleaned ] && [ "$(state "$OURS")" = untouched ] && echo yes || echo no)" \
  "theirs is cleaned and ours untouched" "exit $rc, theirs: $(state "$THEIRS"), ours: $(state "$OURS")"

echo "== only one stack runs Mattermost: it is found without being named"
seed
dc "$THEIRS" stop mattermost >/dev/null 2>&1
retention; rc=$?
check "$([ "$rc" -eq 0 ] && [ "$(state "$OURS")" = cleaned ] && echo yes || echo no)" \
  "ours is found and cleaned" "exit $rc, ours: $(state "$OURS"): $(tail -c 300 "$OUT")"
dc "$THEIRS" start mattermost >/dev/null 2>&1
check "$([ "$(state "$THEIRS")" = untouched ] && echo yes || echo no)" \
  "the other project's postgres, with no Mattermost of its own running, is left alone" "theirs: $(state "$THEIRS")"

echo "== a project with no such service is refused, not guessed"
seed
retention COMPOSE_PROJECT="$RUN-nothing"; rc=$?
check "$([ "$rc" -ne 0 ] && [ "$(state "$OURS")" = untouched ] && [ "$(state "$THEIRS")" = untouched ] && echo yes || echo no)" \
  "it exits non-zero and deletes nothing" "exit $rc, ours: $(state "$OURS"), theirs: $(state "$THEIRS")"

echo "== no compose Mattermost at all: the image search refuses more than one database"
# A Mattermost started without compose, on a host where four containers run a
# postgres image (two stacks, each with its backups container): the search by
# image is the old discovery, and it may no longer take the first.
seed
for p in "$OURS" "$THEIRS"; do dc "$p" stop mattermost >/dev/null 2>&1; done
docker tag busybox:stable "mattermost/mattermost-team-edition:$RUN"
docker run -d --name "$RUN-plain" "mattermost/mattermost-team-edition:$RUN" sleep 300 >/dev/null
retention; rc=$?
for p in "$OURS" "$THEIRS"; do dc "$p" start mattermost >/dev/null 2>&1; done
check "$([ "$rc" -ne 0 ] && said "DB_CONTAINER" && echo yes || echo no)" \
  "it exits non-zero and says to name the database" "exit $rc: $(tail -c 300 "$OUT")"
check "$([ "$(state "$OURS")" = untouched ] && [ "$(state "$THEIRS")" = untouched ] && echo yes || echo no)" \
  "and neither stack lost a row or a file" "ours: $(state "$OURS"), theirs: $(state "$THEIRS")"

echo
echo "passed: $PASSED   failed: $FAILED"
[ "$FAILED" -eq 0 ]
