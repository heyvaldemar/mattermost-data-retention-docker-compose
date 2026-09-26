#!/bin/bash
# What the retention script promises, against a real PostgreSQL with
# Mattermost-shaped tables and a stand-in Mattermost data volume: posts and
# files older than RETENTION days go, files unrecoverably; anything younger
# stays, including something only just inside the window; directories left
# empty are pruned. tests/plant-violations.py breaks each promise in a copy
# of the script and requires this to notice.
#
#   ./tests/e2e-retention.sh        (needs Docker)
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
RUN="retention-e2e-$$"
PASSED=0; FAILED=0
check() { if [ "$1" = yes ]; then echo "  PASS: $2"; PASSED=$((PASSED+1)); else echo "  FAIL: $3"; FAILED=$((FAILED+1)); fi; }
cleanup() { docker rm -f "$RUN-db" "$RUN-mm" >/dev/null 2>&1; docker volume rm "$RUN-data" >/dev/null 2>&1; }
trap cleanup EXIT

DB_PASS="$(openssl rand -hex 16)"
docker run -d --name "$RUN-db" -e POSTGRES_DB=mattermostdb -e POSTGRES_USER=mattermostdbuser \
  -e POSTGRES_PASSWORD="$DB_PASS" postgres:16 >/dev/null
for _ in $(seq 1 60); do docker exec "$RUN-db" pg_isready -q -U mattermostdbuser -d mattermostdb && break; sleep 2; done
sql() { docker exec -e PGPASSWORD="$DB_PASS" "$RUN-db" psql -h 127.0.0.1 -U mattermostdbuser mattermostdb -t -A -c "$1"; }
for _ in $(seq 1 30); do sql 'select 1' >/dev/null 2>&1 && break; sleep 2; done
sql "create table posts (id serial, createat bigint, message text);
     create table fileinfo (id serial, createat bigint, path text, thumbnailpath text, previewpath text);" >/dev/null

# The stand-in Mattermost: a container with the data volume mounted where the
# real one keeps it. The script only reads its volumes.
docker volume create "$RUN-data" >/dev/null
docker run -d --name "$RUN-mm" -v "$RUN-data:/mattermost/data" busybox:stable sleep 600 >/dev/null
docker exec "$RUN-mm" sh -c 'mkdir -p /mattermost/data/old /mattermost/data/recent /mattermost/data/new
  echo x > /mattermost/data/old/expired.txt
  echo x > /mattermost/data/old/expired_thumb.jpg
  echo x > /mattermost/data/recent/kept.txt
  echo x > /mattermost/data/new/current.txt'

ms() { echo $(( ($(date +%s) - $1 * 86400) * 1000 )); }
sql "insert into posts (createat, message) values ($(ms 60), 'old post'), ($(ms 20), 'recent post'), ($(ms 0), 'new post');
     insert into fileinfo (createat, path, thumbnailpath, previewpath) values
       ($(ms 60), 'old/expired.txt', 'old/expired_thumb.jpg', ''),
       ($(ms 20), 'recent/kept.txt', '', ''),
       ($(ms 0), 'new/current.txt', '', '');" >/dev/null

DB_PASS="$DB_PASS" DB_HOST=127.0.0.1 RETENTION=30 INSTALL_CRON=false \
  DB_CONTAINER="$RUN-db" MATTERMOST_CONTAINER="$RUN-mm" HELPER_IMAGE=debian:stable-slim \
  bash mattermost-retention.sh >/dev/null 2>&1
rc=$?
check "$([ "$rc" -eq 0 ] && echo yes || echo no)" "the script completes" "the script exited $rc"

posts="$(sql 'select message from posts order by createat;' | tr '\n' ',')"
check "$([ "$posts" = "recent post,new post," ] && echo yes || echo no)" "posts older than 30 days are gone, younger ones stay" "posts left: ${posts:-none}"
files="$(sql 'select path from fileinfo order by createat;' | tr '\n' ',')"
check "$([ "$files" = "recent/kept.txt,new/current.txt," ] && echo yes || echo no)" "file records older than 30 days are gone" "file records left: ${files:-none}"
there() { if docker exec "$RUN-mm" test -e "/mattermost/data/$1"; then echo yes; else echo no; fi; }
check "$([ "$(there old/expired.txt)" = no ] && echo yes || echo no)" "the expired upload is deleted" "the expired upload is still on disk"
check "$([ "$(there old/expired_thumb.jpg)" = no ] && echo yes || echo no)" "and its thumbnail" "the expired thumbnail is still on disk"
check "$(there recent/kept.txt)" "an upload 20 days old, inside the window, stays" "an upload inside the retention window was deleted"
check "$(there new/current.txt)" "today's upload stays" "today's upload was deleted"
check "$([ "$(there old)" = no ] && echo yes || echo no)" "the directory left empty is pruned" "the emptied directory was left behind"
check "$(there '')" "the data directory itself stays" "the data directory itself was removed"

echo
echo "passed: $PASSED   failed: $FAILED"
[ "$FAILED" -eq 0 ]
