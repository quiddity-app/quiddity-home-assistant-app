# Changelog

An app's version is the Quiddity release it is built from. A change to the app
alone, between releases, adds a number to that: `0.1.0-alpha.2.1`.

## 0.1.0-alpha.2.2

- `initial_graph: restore` restores the graph from the backup's copy of its
  file when there is one, keeping its ID and history, and from the Markdown
  export otherwise.

## 0.1.0-alpha.2.1

- A backup now holds a compressed copy of the graph's file as well as the
  Markdown export, for restoring this node as it was after a disaster.

## 0.1.0-alpha.2

- First version, built from Quiddity v0.1.0-alpha.2.
