# The base is Home Assistant's own, which brings bashio and the s6 overlay that
# supervises the services in rootfs/etc/services.d.
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.23@sha256:b9916671d3df931e47f2f90a219520e091b364c3a05a6d54dc5c9e1545bccf0b

# The node is built from a Quiddity release. Its archives are built for glibc,
# which this image isn't, so it is built from the release's source, as the
# release builds it. Renovate moves these two together, and `version` in
# config.yaml with them (see renovate.json), so that a new Quiddity release is a
# new version of the app.
FROM rust:1.100-alpine3.23@sha256:9577a4edf61be25721f5fa4006ad463b83ea52c0a17c6e6b673c72c794aee738 AS build
# renovate: datasource=github-tags depName=quiddity-app/quiddity extractVersion=^v(?<version>.+)$
ARG QUIDDITY_VERSION=0.1.0-alpha.4
# The commit that tag points to, so that a tag that moves fails the build.
ARG QUIDDITY_REF=4510a4da37c27c03bafbed8d41bb6af46f4e8bc4
# bash is for the release's version script.
# hadolint ignore=DL3018
RUN apk add --no-cache bash build-base git
WORKDIR /src
# Fetching the one commit is much smaller than cloning the history.
RUN git init --quiet . \
  && git fetch --quiet --depth 1 https://github.com/quiddity-app/quiddity "refs/tags/v${QUIDDITY_VERSION}" \
  && test "$(git rev-parse FETCH_HEAD)" = "${QUIDDITY_REF}" \
  && git checkout --quiet FETCH_HEAD
# The checked-in version is a placeholder, which `quiddity-node --version` would
# report. The release stamps the real one in with this script before it builds.
RUN scripts/set-version.sh "${QUIDDITY_VERSION}"
# --locked builds exactly what the release's Cargo.lock says.
RUN --mount=type=cache,target=/usr/local/cargo/registry \
    --mount=type=cache,target=/src/target \
    cargo build --release --locked --package quiddity-node \
  && cp target/release/quiddity-node /quiddity-node

FROM ${BUILD_FROM}
# Alpine keeps busybox's httpd, which serves the ingress page, in a separate
# package. sqlite3 and zstd are for the copy of the graph that a backup holds
# (quiddity-backup-pre). The versions are the base image's Alpine's, so they
# move with it.
# hadolint ignore=DL3018
RUN apk add --no-cache busybox-extras sqlite zstd
COPY --from=build /quiddity-node /usr/local/bin/quiddity-node
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
