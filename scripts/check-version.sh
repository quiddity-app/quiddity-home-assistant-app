#!/usr/bin/env bash
# Checks that the app's version is the Quiddity release it is built from.
# Renovate moves the pin in the Dockerfile and the version in config.yaml
# together, and this fails if only one has moved, which would publish a new
# Quiddity under an old tag, or not publish it at all.
set -euo pipefail

cd "$(dirname "$0")/../quiddity"

quiddity=$(sed -n 's/^ARG QUIDDITY_VERSION=//p' Dockerfile)
version=$(sed -n 's/^version: "\(.*\)"$/\1/p' config.yaml)
[[ -n "${quiddity}" && -n "${version}" ]] || {
  echo "no Quiddity version in the Dockerfile, or no version in config.yaml" >&2
  exit 1
}

# The app's version is Quiddity's, exactly. Home Assistant orders versions with
# AwesomeVersion, which can't order a revision after a pre-release
# (0.1.0-alpha.2.1 is neither older nor newer than 0.1.0-alpha.4), so an app
# on one is never offered an update.
if [[ "${version}" != "${quiddity}" ]]; then
  echo "version ${version} in config.yaml isn't Quiddity ${quiddity} in the Dockerfile" >&2
  exit 1
fi
echo "ok: ${version} is built from Quiddity ${quiddity}"
