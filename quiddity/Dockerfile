# The base is Home Assistant's own, which brings bashio and the s6 overlay that
# supervises the services in rootfs/etc/services.d.
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.24@sha256:5021aac8a4b7f2a1397e23a9749dfe9f736463ffa471df6b200216c68d530fe6

# The node is a Quiddity release's own musl build, which is static and so runs
# on this Alpine image, checked against the release's signed packslip manifest. Renovate moves these two together, and `version` in
# config.yaml with them (see renovate.json), so that a new Quiddity release is a
# new version of the app.
# renovate: datasource=github-tags depName=quiddity-app/quiddity extractVersion=^v(?<version>.+)$
ARG QUIDDITY_VERSION=0.1.0-alpha.5
# The commit that tag points to, so that a tag that moves fails the build.
ARG QUIDDITY_REF=725535e8ff67a9833ad665077b3d7d18bc9b72f0

# Fetching and checking the node is a stage of its own, so that git and Node,
# which the checking needs, aren't in the image.
FROM ${BUILD_FROM} AS fetch
ARG QUIDDITY_VERSION
ARG QUIDDITY_REF
# git is for checking that the tag hasn't moved, and Node is for packslip's
# verifier (packslip-verify.mjs, one file of Node's own modules, copied from
# jdx/packslip at the commit its v1.11.4 points to). The release attests its
# files, but checking that needs a GitHub token, which a build here doesn't have.
# The signed manifest needs none.
# hadolint ignore=DL3018
RUN apk add --no-cache git nodejs
COPY packslip-verify.mjs /usr/local/bin/packslip-verify
WORKDIR /tmp
# The release's archive is named for Rust's target, and the first part of that
# is what `apk --print-arch` says (x86_64 or aarch64). GitHub redirects release
# downloads, and curl is held to https for them. The manifest names the release
# and the workflow that signed it, which must be Quiddity's, and records the
# archive's digest. The node must then say it is the release.
RUN set -eu; \
  tag="v${QUIDDITY_VERSION}"; \
  git ls-remote https://github.com/quiddity-app/quiddity "refs/tags/${tag}" "refs/tags/${tag}^{}" > /tmp/tag; \
  test "$(awk 'END { print $1 }' /tmp/tag)" = "${QUIDDITY_REF}"; \
  archive="quiddity-node-${QUIDDITY_VERSION}-$(apk --print-arch)-unknown-linux-musl.tar.gz"; \
  for file in "${archive}" packslip.sigstore.json; do \
    curl --fail --silent --show-error --location --proto "=https" --proto-redir "=https" --remote-name \
      "https://github.com/quiddity-app/quiddity/releases/download/${tag}/${file}"; \
  done; \
  packslip-verify packslip.sigstore.json \
    --issuer https://token.actions.githubusercontent.com \
    --source-repository https://github.com/quiddity-app/quiddity \
    --project github.com/quiddity-app/quiddity \
    --tag "${tag}" \
    --artifact "${archive}"; \
  tar -xzf "${archive}" -C /usr/local/bin quiddity-node; \
  test "$(quiddity-node --version)" = "quiddity-node ${QUIDDITY_VERSION}"

FROM ${BUILD_FROM}
# Alpine keeps busybox's httpd, which serves the ingress page, in a separate
# package. sqlite3 and zstd are for the copy of the graph that a backup holds
# (quiddity-backup-pre). The versions are the base image's Alpine's, so they
# move with it.
# hadolint ignore=DL3018
RUN apk add --no-cache busybox-extras sqlite zstd
COPY --from=fetch /usr/local/bin/quiddity-node /usr/local/bin/quiddity-node
COPY rootfs /
# The node keeps the device's key in a configuration directory, which it finds
# from HOME, and so in the container's own filesystem, which a restart throws
# away. Every restart then gave the node a new key, and so a new device ID that
# nobody had been told. /data is the one place that survives.
ENV QUIDDITY_CONFIG_DIR=/data/config
LABEL org.opencontainers.image.title="Quiddity" \
  org.opencontainers.image.description="An always-on Quiddity node for Home Assistant" \
  org.opencontainers.image.source="https://github.com/quiddity-app/quiddity-home-assistant-app" \
  org.opencontainers.image.licenses="Apache-2.0"
