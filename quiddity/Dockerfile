# The base is Home Assistant's own, which brings bashio and the s6 overlay that
# supervises the services in rootfs/etc/services.d.
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.23

# The node is built from a Quiddity release. Its archives are built for glibc,
# which this image isn't, so it is built from the release's source, as the
# release builds it. Renovate moves these two together, and `version` in
# config.yaml with them (see renovate.json), so that a new Quiddity release is a
# new version of the app.
FROM rust:1.100-alpine3.23 AS build
# renovate: datasource=github-tags depName=quiddity-app/quiddity extractVersion=^v(?<version>.+)$
ARG QUIDDITY_VERSION=0.1.0-alpha.2
# The commit that tag points to, so that a tag that moves fails the build.
ARG QUIDDITY_REF=fbc1d09fdf2d6741f8b8a322e260319181cb182d
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
# package. The versions are the base image's Alpine's, so they move with it.
# hadolint ignore=DL3018
RUN apk add --no-cache busybox-extras
COPY --from=build /quiddity-node /usr/local/bin/quiddity-node
COPY rootfs /
LABEL org.opencontainers.image.title="Quiddity" \
  org.opencontainers.image.description="An always-on Quiddity node for Home Assistant" \
  org.opencontainers.image.source="https://github.com/quiddity-app/quiddity-home-assistant-app" \
  org.opencontainers.image.licenses="Apache-2.0"
