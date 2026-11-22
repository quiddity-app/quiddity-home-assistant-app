#!/usr/bin/env bash
# Checks that the app's version follows the Quiddity release it is built from,
# and that the changelog says so. Renovate moves the pin in the Dockerfile and
# the version in config.yaml together, and this fails if only one has moved,
# which would publish a new Quiddity under an old tag, or not publish it at all.
set -euo pipefail

cd "$(dirname "$0")/../quiddity"

quiddity=$(sed -n 's/^ARG QUIDDITY_VERSION=//p' Dockerfile)
version=$(sed -n 's/^version: "\(.*\)"$/\1/p' config.yaml)
[[ -n "${quiddity}" && -n "${version}" ]] || {
  echo "no Quiddity version in the Dockerfile, or no version in config.yaml" >&2
  exit 1
}

# The app's version is Quiddity's, and may have a revision after it, for a change
# to the app alone: 0.1.0-alpha.2 is followed by 0.1.0-alpha.2.1.
if [[ "${version}" != "${quiddity}" && "${version}" != "${quiddity}".[0-9]* ]]; then
  echo "version ${version} in config.yaml doesn't follow Quiddity ${quiddity} in the Dockerfile" >&2
  exit 1
fi

grep -q "^## ${version}\$" CHANGELOG.md || {
  echo "CHANGELOG.md has no entry for ${version}" >&2
  exit 1
}
echo "ok: ${version} is built from Quiddity ${quiddity}"
