# Quiddity for Home Assistant

A [Home Assistant](https://www.home-assistant.io) app that runs a
[Quiddity](https://github.com/quiddity-app/quiddity) node: a copy of your graph
that is always on, so your devices sync through it without being online
together.

- **Backs up with Home Assistant, without stopping.** Just before a backup the
  node writes its graph as Markdown, and the backup holds that rather than a
  copy of files that are being written to. It can be restored, and read without
  Quiddity.
- **Sync is set up from the sidebar.** The node's device ID is shown in
  Quiddity's panel, and the devices that may connect are a setting.
- Runs on `amd64` and `aarch64`.

Quiddity has no release yet, so the node is built from one pinned commit of its
repository (see [the Dockerfile](quiddity/Dockerfile)).

## Installing

In Home Assistant, open **Settings → Apps → App store**, choose **Repositories**
from the menu and add:

```text
https://github.com/quiddity-app/quiddity-home-assistant-app
```

Then install **Quiddity**, start it and open it from the sidebar. How to
connect your devices is in [the app's documentation](quiddity/DOCS.md).

## Working on it

See [AGENTS.md](AGENTS.md). With [mise](https://mise.jdx.dev), `mise run check`
does what CI does: it lints, builds the image and runs it against a stand-in for
the Supervisor. The repository also has the devcontainer that Home Assistant
recommends for running an app in a real Supervisor.

## Licence

Apache 2.0. See [LICENSE](LICENSE).
