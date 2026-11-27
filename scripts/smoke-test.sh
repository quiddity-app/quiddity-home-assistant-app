#!/usr/bin/env bash
# Runs the app's image the way Home Assistant does, against a stand-in for the
# Supervisor, and checks what a person relies on: the sidebar page shows the
# device ID, a stop is clean, a backup's copy of the graph opens, and either the
# copy or the export can be restored.
#
# Usage: scripts/smoke-test.sh IMAGE
#
# The stand-in is the image's own httpd serving the one answer that bashio asks
# the Supervisor for, the app's options. There is no other way to run bashio
# without one, since `bashio::config` doesn't read /data/options.json.
set -euo pipefail

image=${1:?usage: smoke-test.sh IMAGE}
run=$$
network="quiddity-test-$run"
declare -a volumes=()
declare -a containers=()

cleanup() {
  docker rm --force "${containers[@]}" > /dev/null 2>&1 || true
  docker volume rm --force "${volumes[@]}" > /dev/null 2>&1 || true
  docker network rm "${network}" > /dev/null 2>&1 || true
  rm -rf "${scratch:-}"
}
trap cleanup EXIT
scratch=$(mktemp -d)

fail() {
  echo "FAIL: $*" >&2
  for container in "${containers[@]}"; do
    echo "--- logs of ${container}" >&2
    docker logs "${container}" >&2 2>&1 || true
  done
  exit 1
}

docker network create "${network}" > /dev/null

# The Supervisor, answering for the app's options: `options '{"log_level": ...}'`.
mkdir -p "${scratch}/www/addons/self/options"
docker run --detach --name "supervisor-${run}" --network "${network}" \
  --network-alias supervisor --volume "${scratch}/www:/www:ro" \
  --entrypoint httpd "${image}" -f -p 80 -h /www > /dev/null
containers+=("supervisor-${run}")

options() {
  printf '{"result": "ok", "data": %s}\n' "$1" > "${scratch}/www/addons/self/options/config"
}

volume() {
  local name="quiddity-test-$run-$1"
  docker volume create "${name}" > /dev/null
  volumes+=("${name}")
  echo "${name}"
}

start() {
  local name=$1 data=$2
  docker run --detach --name "${name}" --network "${network}" \
    --env SUPERVISOR_TOKEN=test --volume "${data}:/data" "${image}" > /dev/null
  containers+=("${name}")
}

# Whether a container has logged a line. The log is read whole first: grep -q
# stops reading at the first match, and docker logs then fails, which pipefail
# would count against the match.
logged() {
  local logs
  logs=$(docker logs "$1" 2>&1)
  grep -q -- "$2" <<< "${logs}"
}

wait_for() {
  local name=$1 pattern=$2
  for _ in $(seq 1 60); do
    if logged "${name}" "${pattern}"; then
      return 0
    fi
    sleep 1
  done
  fail "${name} never logged '${pattern}'"
}

# Stops the app, as Home Assistant does, and checks it went quietly.
stop() {
  local name=$1
  docker stop --time 30 "${name}" > /dev/null
  if logged "${name}" "stopped with status"; then
    fail "${name} didn't stop cleanly"
  fi
}

page() {
  docker exec "$1" wget --quiet --output-document=- http://127.0.0.1:8099/
}

# What the page's status script gives: the node's own answer, or an error when
# it isn't serving. Either way, JSON that says which.
status() {
  docker exec "$1" wget --quiet --output-document=- http://127.0.0.1:8099/cgi-bin/status
}

# A device that may connect. Any valid ID will do: nothing connects.
peer=$(docker run --rm --entrypoint quiddity-node "${image}" --graph /tmp/peer init --blank)

echo "== Nobody is allowed yet: the node waits and the page shows its ID"
options '{"allowed_devices": [], "initial_graph": "empty", "log_level": "warn"}'
data=$(volume waiting)
start waiting "${data}"
wait_for waiting "No device is allowed to connect yet"
id=$(docker logs waiting 2>&1 | sed -n "s/.*device ID is \([0-9a-f]\{64\}\).*/\1/p")
[[ -n "${id}" ]] || fail "no device ID in the log"
page waiting | grep -q "${id}" || fail "the page doesn't show ${id}"
page waiting | grep -q 'id="state"' || fail "the page has no sync status"
status waiting | grep -q '"error"' || fail "a node that isn't serving reported a status"
docker exec waiting quiddity-backup-pre || fail "a backup of a node that isn't serving failed"
stop waiting

echo "== A device is allowed: the node serves, and a backup exports the graph"
options "{\"allowed_devices\": [\"${peer}\"], \"initial_graph\": \"empty\", \"log_level\": \"warn\"}"
data=$(volume serving)
# A graph that has something in it, which the app finds and doesn't recreate.
mkdir -p "${scratch}/markdown/entities"
printf 'title:: Hello\n\n- A block\n' > "${scratch}/markdown/entities/Hello.md"
docker run --rm --volume "${data}:/data" --volume "${scratch}/markdown:/markdown:ro" \
  --entrypoint sh "${image}" -c \
  'quiddity-node --graph /data/graph init > /dev/null && quiddity-node --graph /data/graph import /markdown > /dev/null'
# The graph's own ID, to see that a restore from the copy is the same graph.
graph_id=$(docker run --rm --volume "${data}:/data" --entrypoint quiddity-node "${image}" \
  --graph /data/graph identify)
[[ -n "${graph_id}" ]] || fail "the graph has no ID"
start serving "${data}"
wait_for serving "^serving "
# The node binds its status port just after it says it is serving.
for _ in $(seq 1 10); do
  status serving | grep -q '"state"' && break
  sleep 1
done
status serving | grep -q '"state"' || fail "a serving node gave no sync state"
docker exec serving quiddity-backup-pre || fail "the backup hook failed"
docker exec serving test -f /data/export/entities/Hello.md || fail "the export has no Hello.md"
# The copy of the graph's file: private, no half-made leftovers, and a graph that
# opens, with what was imported in it. It is read in the running app, where the
# node is still serving, as a restore would find it.
docker exec serving sh -c '
  set -e
  copy=/data/database/graph.quiddity.zst
  test -s "${copy}"
  test "$(stat -c %a "${copy}")" = 600
  test -z "$(ls /data/database | grep "\.part$" || true)"
  mkdir /tmp/copy
  zstd --quiet --decompress --stdout "${copy}" > /tmp/copy/graph.quiddity
  quiddity-node --graph /tmp/copy/graph.quiddity export /tmp/copy/out > /dev/null
  grep -rq "A block" /tmp/copy/out
' || fail "the backup has no usable copy of the graph's file"
stop serving
# Home Assistant restarts the app on the same /data, in a new container. The node's
# key must be in /data, or each restart gives it a new device ID.
id=$(docker logs serving 2>&1 | sed -n "s/.*device ID is \([0-9a-f]\{64\}\).*/\1/p")
[[ -n "${id}" ]] || fail "no device ID in the log"
docker run --rm --volume "${data}:/data" --entrypoint test "${image}" -f /data/config/device.key \
  || fail "the device key isn't in /data"
start restarted "${data}"
wait_for restarted "^serving "
logged restarted "no device key" && fail "restarted without its device key"
logged restarted "device ID is ${id}" || fail "the device ID changed with a restart"
stop restarted

echo "== Restoring: only the export is in the backup, and the app has already started"
mkdir -p "${scratch}/backup"
docker cp "serving:/data/export/." "${scratch}/backup"
restored=$(volume restored)
docker run --rm --volume "${restored}:/data" --volume "${scratch}/backup:/backup:ro" \
  --entrypoint sh "${image}" -c 'mkdir /data/export && cp -r /backup/. /data/export'
# Home Assistant starts the restored app as it was configured, making an empty graph.
options "{\"allowed_devices\": [\"${peer}\"], \"initial_graph\": \"empty\", \"log_level\": \"warn\"}"
start empty "${restored}"
wait_for empty "^serving "
stop empty
options "{\"allowed_devices\": [\"${peer}\"], \"initial_graph\": \"restore\", \"log_level\": \"warn\"}"
start restored "${restored}"
wait_for restored "^serving "
logged restored "Restoring the graph" || fail "didn't say it restored"
stop restored
# Asked again, it doesn't restore over a graph that has something in it.
start again "${restored}"
wait_for again "^serving "
logged again "not restoring over it" || fail "restored over a graph"
stop again
# What was backed up is in the graph, not only in the export that was restored.
docker run --rm --volume "${restored}:/data" --entrypoint sh "${image}" -c \
  'quiddity-node --graph /data/graph export /tmp/check > /dev/null && grep -rq "A block" /tmp/check' \
  || fail "the restored graph doesn't have what was backed up"

echo "== Restoring from the copy of the graph's file: it is the same graph"
mkdir -p "${scratch}/database"
docker cp "serving:/data/database/." "${scratch}/database"
copied=$(volume copied)
docker run --rm --volume "${copied}:/data" --volume "${scratch}/database:/database:ro" \
  --entrypoint sh "${image}" -c 'mkdir /data/database && cp -a /database/. /data/database'
options "{\"allowed_devices\": [\"${peer}\"], \"initial_graph\": \"empty\", \"log_level\": \"warn\"}"
start blank "${copied}"
wait_for blank "^serving "
stop blank
options "{\"allowed_devices\": [\"${peer}\"], \"initial_graph\": \"restore\", \"log_level\": \"warn\"}"
start copied "${copied}"
wait_for copied "^serving "
logged copied "Restored the graph from the copy" || fail "didn't say it restored the copy"
stop copied
docker run --rm --volume "${copied}:/data" --entrypoint sh "${image}" -c \
  'test "$(quiddity-node --graph /data/graph identify)" = "$1" \
    && quiddity-node --graph /data/graph export /tmp/check > /dev/null && grep -rq "A block" /tmp/check' \
  sh "${graph_id}" || fail "the graph restored from the copy isn't the one that was backed up"

echo "passed"
