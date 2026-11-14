#!/usr/bin/with-contenv bashio
# shellcheck shell=bash
# Makes the graph the first time, and the page that Home Assistant shows for it
# in the sidebar, every time.

readonly GRAPH=/data/graph
# Where the node writes its Markdown export, which is what a backup holds.
readonly EXPORT=/data/export

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
  elif [[ -f "${EXPORT}/quiddity.json" ]]; then
    mv "${GRAPH}/graph.quiddity" "${GRAPH}/graph.quiddity.empty"
    create=restore
  fi
fi

if [[ "${create}" == restore && ! -f "${EXPORT}/quiddity.json" ]]; then
  bashio::log.warning "There is no export from a backup to restore, so starting empty"
  create=empty
fi

if [[ -n "${create}" ]]; then
  mkdir -p "${GRAPH}"
  case "${create}" in
    restore)
      bashio::log.info "Restoring the graph from the export in the backup"
      bashio::log.warning "This node has a new device ID, so add it again on your devices"
      quiddity-node --graph "${GRAPH}" init > /dev/null
      quiddity-node --graph "${GRAPH}" import "${EXPORT}"
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
