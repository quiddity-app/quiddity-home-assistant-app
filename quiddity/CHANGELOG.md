# Changelog

An app's version is the Quiddity release it is built from. A change to the app
alone, between releases, adds a number to that: `0.1.0-alpha.2.1`.

## 0.1.0-alpha.2.3

- The node's device key is kept in `/data/config`, so it survives a restart.
  Before, it was in the container's own filesystem, and each restart made a new
  key and so a new device ID, which broke sync until the new one was added on
  your other devices. **This update does that one last time**: add the device ID
  the app shows after it, and it stays the same from then on. It is not in
  backups, as before.
- The app warns when it finds a graph but no device key, since the device ID
  has then changed.

## 0.1.0-alpha.2.2

- `initial_graph: restore` restores the graph from the backup's copy of its
  file when there is one, keeping its ID and history, and from the Markdown
  export otherwise.

## 0.1.0-alpha.2.1

- A backup now holds a compressed copy of the graph's file as well as the
  Markdown export, for restoring this node as it was after a disaster.

## 0.1.0-alpha.2

- First version, built from Quiddity v0.1.0-alpha.2.
