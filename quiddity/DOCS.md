# Quiddity

This runs a [Quiddity](https://github.com/quiddity-app/quiddity) node beside
Home Assistant. It holds a full copy of your graph and is always on, so your
phone and your laptop can catch up with each other without ever being awake at
the same time. It has no editor of its own: you work in Quiddity's app on your
devices.

## Connecting your devices

Devices let each other in by ID, and nothing else can connect.

1. Open **Quiddity** in the sidebar. It shows this node's device ID, and below
   it, how the node stands with your other devices: alone, offline, behind or
   synced, and which of the devices it knows are connected now.
2. In Quiddity on a device you already use, open **Devices**, and add that ID.
3. Copy that device's own ID from the same page, and put it in **Allowed
   devices** on this app's Configuration tab. Restart the app.

They connect by themselves from then on, over the internet, so the devices need
not be on your home network. Once one device is in, it lets in the others, so
the allowed list only has to name the first.

By default this node starts with an empty graph and receives yours from the
first device that connects. That is nearly always right. See **Initial graph**
below for the others.

## Backups

Home Assistant's backups are **hot**: the app keeps running. Just before one,
the node writes its graph as Markdown into the app's data, and the backup holds
that and not the node's own files, which can't be copied safely while it writes
to them. The Markdown can be read without Quiddity.

The backup also holds `database/graph.quiddity.zst`: a consistent, compressed
copy of the graph's file, taken with SQLite's `VACUUM INTO` while the node runs
(its saves wait for the copy). It is the graph as it is, with its ID, its
history and its files, and it is built the same way each time, so successive
backups differ little. It is private to this app, and may hold keys that make the
node this node, so treat the backup accordingly.

A backup does not hold:

- **The device key.** It lives outside the graph's file, so a restored node can
  have a different device ID, which your devices need to be told. It is the
  graph that is restored, not the device.
- **Files in the Markdown export** (images, PDFs and the like). They are in the
  copy of the graph's file.

### Restoring

Your other devices hold the whole graph too, so in the usual case there is
nothing to restore: restore the backup (or start a new app), leave **Initial
graph** on `empty`, add the node's new ID on your devices, and let them sync.

If this node was the **only** copy, or all of them are lost, restore the backup,
then set **Initial graph** to `restore` and restart the app. If the backup holds
the copy of the graph's file, the node takes that: the same graph, with its ID,
its history and its files, which the devices that still have a version of it
can sync with. The device ID may differ. Restore only when no other node is
running this graph, since two that share one would each carry on as the other.

Without the copy (a backup made before it existed), the node builds the graph
from the Markdown export instead. That is a new graph that happens to have your
content, with no shared history with any device that still has the old one, so
syncing the two would show everything twice. Restore that way only when nothing
else has the graph.

Either way, it never replaces a graph that already holds something.

## Options

| Option | Meaning |
|---|---|
| `allowed_devices` | The IDs of devices that may connect: 64 hexadecimal digits each. |
| `initial_graph` | What to start with, the first time. `empty` (the default) receives the graph from a device you already have. `new` makes a new graph here, which can't later be merged with another that began separately. `restore` is described above. |
| `log_level` | `error`, `warn` (the default), `info`, `debug` or `trace`. `info` is chatty. |

## Not built yet

- Removing a device: Quiddity can't yet take a device away once it has been let
  in.
- Reading and editing the graph from Home Assistant itself.
- A fixed port: the node finds other devices through iroh's relays and holes
  punched in the network, so it needs no port forwarding.
