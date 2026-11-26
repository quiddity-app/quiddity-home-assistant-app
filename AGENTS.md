# Working on the Quiddity Home Assistant app

Notes for anyone (person or agent) changing this repository. It is a Home
Assistant app (what used to be called an add-on) that runs a
[Quiddity](https://github.com/quiddity-app/quiddity) node. Quiddity's own
[AGENTS.md](https://github.com/quiddity-app/quiddity/blob/main/AGENTS.md) says
how we work there, and the same applies here.

## Git

- **One commit per pull request**, each building and passing on its own;
  a change that depends on another is stacked on it. Fix-ups are squashed into
  the commit they fix.
- **Rebase, never merge**, and rebase-merge PRs. Fetch `main` immediately before
  rebasing, and push with `--force-with-lease`.
- Commit messages say why, not just what, in plain prose.

## Writing

British English, in code, comments, docs and commit messages. Comments explain
what isn't obvious from the code.

## What is where

- `quiddity/` is the app, and the only thing Home Assistant reads: `config.yaml`
  (its manifest), `Dockerfile`, `rootfs/` (copied into the image) and the pages
  the Supervisor shows (`DOCS.md`, `README.md`, `CHANGELOG.md`, `translations/`).
- `scripts/smoke-test.sh` runs the image against a stand-in for the Supervisor,
  and `scripts/check-version.sh` that the version follows Quiddity's.
- `.github/workflows/build.yml` runs that on ARM, and on main publishes the
  images for each architecture, when a change to the app reaches main or when it
  is run by hand there; `pre-commit.yml` runs the hooks.
- `.devcontainer.json` and `.vscode/` are for running the app in a real
  Supervisor.

## Things that aren't obvious

- **The app's version is the Quiddity release it is built from.** The Dockerfile
  builds the node from the release's tag (`QUIDDITY_VERSION`, with the commit it
  points to in `QUIDDITY_REF`, so that a tag that moves fails the build), and
  `version` in `config.yaml` is the same string. Renovate moves all three in one
  pull request (`renovate.json`), because an image's tag is the app's version
  and **a tag is never reused**: a new Quiddity must be a new version, or it
  would never reach anyone. `scripts/check-version.sh` fails CI if the two have
  come apart, or the changelog has no entry for the version, so a Renovate pull
  request needs a line in `CHANGELOG.md` added to it before it can merge.
  It is built from source, not from the release's archives, because those are
  for glibc and the image is Alpine; the build stamps the version in with the
  release's own `scripts/set-version.sh`, as the release does, so that
  `quiddity-node --version` says what it is.
- **A change to the app alone, between Quiddity releases, adds a revision**:
  `0.1.0-alpha.2.1`. Anything in `quiddity/` that reaches the image needs one,
  with a changelog entry; the build skips a version that is already published,
  which would otherwise leave the old image under it silently. Base image bumps
  from Renovate are the one change that doesn't get one, and they reach users
  with the next Quiddity release.
- **Backups are hot, and hold an export, not the graph's files.** The graph is a
  SQLite file and the blobs another database, and a copy taken mid-write can be
  torn. So `backup_pre` (`quiddity-backup-pre`) sends the node SIGUSR1, which
  makes `serve --export` write Markdown to `/data/export`, and `backup_exclude`
  leaves `graph/` out. The hook knows the export is done when the directory's
  inode changes, since the node builds it beside and renames it over. It waits
  until the node is 30 seconds old, because SIGUSR1 kills it before the handler
  is installed. A cold backup of the live files is the alternative, and
  loses nothing but takes the app down; the export loses the identity and the
  files (below).
- **What the export loses is deliberate or Quiddity's to fix.** The identity is
  in `graph.quiddity`, so a restore has a new one, which also means it can't
  duplicate one. The export from `serve` has no `assets/` (the CLI's `export`
  does), so files come back only by syncing; `serve --export` writing them is
  the change to make in Quiddity. Restoring by import makes a graph unrelated
  to any device's copy (graph IDs aren't built), so `initial_graph: restore` is
  only for when nothing else has the graph, and the docs say so.
- **Everything the node keeps is in `/data`**, including its identity: the graph's
  own in `graph/graph.quiddity`, and the device key in `config/`, which the
  Dockerfile's `QUIDDITY_CONFIG_DIR` points the node at. Without that the node
  used `$HOME/.config/quiddity`, inside the container, and every restart made a
  new key and so a new device ID: a graph made since the key was kept apart
  derives its endpoint key from it. A backup leaves both out, so restoring never
  gives two nodes one identity. The key's absence beside a graph can't be made an
  error, since it is how an app from before this change starts, so the init
  script warns instead.
- **The node stops only on SIGINT, and a stop sends SIGTERM to everything.** So
  the node is started with SIGTERM ignored (an ignored signal survives `exec`)
  and the run script's trap forwards an interrupt, then exits 0, because a
  requested stop isn't a failure and `finish` halts the app on one. Without the
  ignore, the node died of the same SIGTERM, unsaved.
- **`restore` only replaces a graph with no entities.** A restored backup has no
  graph, so the app usually starts, makes an empty one, and only then can be
  asked to restore. "Empty" is the entity count of an export of it: "lists no
  devices" looked the same and wasn't, because a save records a device one save
  late. The empty file is kept as `graph.quiddity.empty`.
- **The graph starts blank** unless `initial_graph` says otherwise: the node is a
  replica for devices that already hold the graph. A blank replica can't be
  written to before it has joined, which is why it can't be imported into.
- **No `image` means building on the device**, which compiles the node on
  whatever the user has, and can be too much for a Raspberry Pi. Remove `image`
  from `config.yaml` to test the Dockerfile through a local repository; don't
  commit that.
- **bashio's `config` output has no trailing newline**, so `while read` drops the
  last value. Use `mapfile`. The smoke test found this.
- **The ingress page is static**, written at start, because the node's store
  allows one process at a time and so can't be asked who is connected.
- Scripts under `rootfs` run under bashio and have no extension, so the
  pre-commit hook for shellcheck matches them by path.

## Testing

Nothing here is Rust, so the test is the image, run the way Home Assistant runs
it (`scripts/smoke-test.sh`, `mise run test`). `bashio::config` asks the
Supervisor for the options and doesn't read `/data/options.json`, so the test
stands in for the Supervisor: the image's own `httpd` serves the one answer
bashio asks for, and `SUPERVISOR_API` could point it anywhere else. It starts
the app with nobody allowed, with a device allowed and takes a backup, and
restores one. Add a scenario there when you add behaviour.

For the real Supervisor, the repository has the devcontainer that Home
Assistant's own example uses (`.devcontainer.json`, and tasks in `.vscode/`):
open it in VS Code, run **Start Home Assistant**, and install the app from the
local apps.

CI runs the test on an ARM runner, since that is what the app is hosted on, and
publishes both architectures from main. amd64 is built there, but not run.
**`test` is a required check, so it runs on every pull request**: don't put a
`paths` filter on `pull_request` in `build.yml`, or a pull request that touches
other files will wait for it for ever. (The push is filtered, since all it does
is publish.) The cost is a compile on pull requests that don't need one.

The first publish makes a **private** package, which Home Assistant can't pull
(it says `denied`, with a 403 and a 401). Make it public once, in the
organisation's package settings. Nothing a workflow can do changes that.

## Checking

`mise run check` lints, builds and runs the image, and runs the hooks, which are
what CI runs (`mise run build` alone compiles the node, slowly the first time).
Pre-commit's zizmor needs the GitHub API: in a sandbox without it, it fails
without auditing anything. CI runs it.
