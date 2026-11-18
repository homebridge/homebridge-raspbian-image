#!/usr/bin/env bash
# Prints the versions an image is built from, one NAME=value per line.
#
# Usage: package-versions.sh [stream | path to a package.json]     (default: stable)
#
# The versions come from <stream>/package.json, which the dependency bot keeps up to date.
# Every version must be one exact version. A range ("^1.2.3"), "*" or a tag ("latest") stops the
# script, so a build can never take "whatever is newest today".
set -euo pipefail

SOURCE="${1:-stable}"

if [ -f "$SOURCE" ]; then
  FILE="$SOURCE"
elif [[ "$SOURCE" =~ ^[a-z]+$ ]]; then
  FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/${SOURCE}/package.json"
else
  echo "package-versions.sh: not a stream name or a file: ${SOURCE}" >&2
  exit 1
fi

exact_version() {
  local name="$1" version
  version="$(jq -r --arg name "$name" '.dependencies[$name] // empty' "$FILE")"
  if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
    echo "package-versions.sh: ${name} in ${FILE} must be one exact version, found: '${version}'" >&2
    exit 1
  fi
  printf '%s' "$version"
}

APT_PKG="$(exact_version "@homebridge/homebridge-apt-pkg")"
FFMPEG="$(exact_version "ffmpeg-for-homebridge")"
WIFI_CONNECT="$(exact_version "@homebridge/wifi-connect")"

echo "HOMEBRIDGE_APT_PKG_VERSION=${APT_PKG}"
echo "FFMPEG_FOR_HOMEBRIDGE_VERSION=v${FFMPEG}"
echo "WIFI_CONNECT_VERSION=${WIFI_CONNECT}"
