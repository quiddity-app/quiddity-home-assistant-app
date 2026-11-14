# Quiddity

This runs a [Quiddity](https://github.com/quiddity-app/quiddity) node beside
Home Assistant. It holds a full copy of your graph and is always on, so your
phone and your laptop can catch up with each other without ever being awake at
the same time. It has no editor of its own: you work in Quiddity's app on your
devices.

## Connecting your devices

Devices let each other in by ID, and nothing else can connect.

1. Open **Quiddity** in the sidebar. It shows this node's device ID.
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

A backup does not hold:

- **The node's device ID.** A restored node has a new one, which your devices
  need to be told. Its sync identity is therefore never copied to a second
  place, which is the one hazard in restoring a graph that Quiddity can't yet
  guard against itself.
- **Files in the graph** (images, PDFs and the like). The export doesn't carry
  them yet. Your other devices keep them, and the node fetches them again when
  it syncs.

### Restoring

Your other devices hold the whole graph too, so in the usual case there is
nothing to restore: restore the backup (or start a new app), leave **Initial
graph** on `empty`, add the node's new ID on your devices, and let them sync.

If this node was the **only** copy, restore the backup, then set **Initial
graph** to `restore` and restart the app. It builds the graph from the export,
unless the graph already holds something, which it never replaces. The result
is a new graph that happens to have your content, with no shared history with
any device that still has the old one, so syncing the two would show
everything twice. Restore only when nothing else has the graph.

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
