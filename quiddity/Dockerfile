# The base is Home Assistant's own, which brings bashio and the s6 overlay that
# supervises the services in rootfs/etc/services.d.
ARG BUILD_FROM=ghcr.io/home-assistant/base:3.23

# Quiddity has no release yet, so the node is built from one pinned commit of
# its repository. Renovate moves the pin; whoever merges that must also bump
# `version` in config.yaml, because an image tag is never reused.
FROM rust:1.100-alpine3.23 AS build
# renovate: datasource=git-refs depName=https://github.com/quiddity-app/quiddity currentValue=main
ARG QUIDDITY_REF=5541e5d4d466d9415a3bbea63e68a5d3b94c686d
# The packages are the builder image's own Alpine's, so they move with it.
# hadolint ignore=DL3018
RUN apk add --no-cache build-base git
WORKDIR /src
# Fetching the one commit by hash is much smaller than cloning the history.
RUN git init --quiet . \
  && git fetch --quiet --depth 1 https://github.com/quiddity-app/quiddity "$QUIDDITY_REF" \
  && git checkout --quiet FETCH_HEAD
# --locked builds exactly what the pinned commit's Cargo.lock says.
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
