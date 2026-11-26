#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# Makes the graph the first time, and the page that Home Assistant shows for it
# in the sidebar, every time.

readonly GRAPH=/data/graph
# What a backup holds: the Markdown export, and a compressed copy of the graph's
# file, both made by quiddity-backup-pre.
readonly EXPORT=/data/export
readonly COPY=/data/database/graph.quiddity.zst

initial=$(bashio::config 'initial_graph')
create=""
if [[ ! -f "${GRAPH}/graph.quiddity" ]]; then
  create=${initial}
elif [[ "${initial}" == restore ]]; then
  # A restored backup has no graph, so the app has usually started and made an
  # empty one before anyone could ask for this. That is safe to replace, and
  # nothing with anything in it is.
  entities=$(quiddity-node --graph "${GRAPH}" export /tmp/check | sed -n 's/^exported \([0-9]*\) entities.*/\1/p')
  rm -rf /tmp/check
  if [[ "${entities}" != 0 ]]; then
    bashio::log.info "There is a graph already, so not restoring over it"
  elif [[ -f "${COPY}" || -f "${EXPORT}/quiddity.json" ]]; then
    mv "${GRAPH}/graph.quiddity" "${GRAPH}/graph.quiddity.empty"
    create=restore
  fi
fi

if [[ "${create}" == restore && ! -f "${COPY}" && ! -f "${EXPORT}/quiddity.json" ]]; then
  bashio::log.warning "There is nothing from a backup to restore, so starting empty"
  create=empty
fi

# Puts the backup's copy of the graph's file in place, and says whether it
# opens. The copy is the graph as it was, with its ID and its history, so the
# devices that still have it can sync with it. It is unpacked beside where it
# goes and renamed, and the owner alone can read it, as the node makes it.
unpack_copy() {
  [[ -f "${COPY}" ]] || return 1
  mkdir -p "${GRAPH}"
  (
    umask 077
    zstd --quiet --decompress --force -o "${GRAPH}/graph.quiddity.part" "${COPY}"
  ) || return 1
  if ! quiddity-node --graph "${GRAPH}/graph.quiddity.part" export /tmp/check > /dev/null; then
    rm -rf "${GRAPH}/graph.quiddity.part" /tmp/check
    return 1
  fi
  rm -rf /tmp/check
  mv "${GRAPH}/graph.quiddity.part" "${GRAPH}/graph.quiddity"
}

if [[ -n "${create}" ]]; then
  mkdir -p "${GRAPH}"
  case "${create}" in
    restore)
      if unpack_copy; then
        bashio::log.info "Restored the graph from the copy in the backup"
        bashio::log.warning "Restore only when no other node is running this graph"
        bashio::log.warning "The device ID may have changed, so check it on your devices"
      elif [[ -f "${EXPORT}/quiddity.json" ]]; then
        bashio::log.info "Restoring the graph from the export in the backup"
        bashio::log.warning "This node has a new device ID, so add it again on your devices"
        quiddity-node --graph "${GRAPH}" init > /dev/null
        quiddity-node --graph "${GRAPH}" import "${EXPORT}"
      else
        bashio::log.warning "The backup's copy of the graph won't open, and it has no export, so starting empty"
        quiddity-node --graph "${GRAPH}" init --blank > /dev/null
      fi
      ;;
    new)
      bashio::log.info "Creating a new graph"
      quiddity-node --graph "${GRAPH}" init > /dev/null
      ;;
    *)
      # A blank replica has nothing of its own to conflict with the graph it
      # will be sent. It must join one by syncing before anything is written to it.
      bashio::log.info "Creating an empty graph, to receive one from your other devices"
      quiddity-node --graph "${GRAPH}" init --blank > /dev/null
      ;;
  esac
fi

# The device ID comes from a key kept apart from the graph, in /data/config. A
# graph with no key beside it gets a new one, and so a new device ID, which the
# devices that had the old one won't recognise. That is what every restart used
# to do, before the key was kept in /data, so say so rather than let sync fail
# without a reason. (A graph just made or restored has said its own piece.)
if [[ -z "${create}" && ! -f "${QUIDDITY_CONFIG_DIR:-/data/config}/device.key" ]]; then
  bashio::log.warning "There is a graph but no device key, so this node has a new device ID"
  bashio::log.warning "Add it again on your devices, and it will stay the same from now on"
fi

device_id=$(quiddity-node --graph "${GRAPH}" id)
bashio::log.info "This node's device ID is ${device_id}"

# The ID is hexadecimal, so it needs no escaping in HTML.
allowed=""
mapfile -t devices < <(bashio::config 'allowed_devices')
for device in "${devices[@]}"; do
  allowed+="<li><code>${device}</code></li>"
done
if [[ -z "${allowed}" ]]; then
  allowed="<li class=\"none\">None yet. Add one in the app's configuration.</li>"
fi

mkdir -p /var/www
sed -e "s/@DEVICE_ID@/${device_id}/g" \
    -e "s|@ALLOWED@|${allowed}|" \
    /usr/share/quiddity/index.html > /var/www/index.html
