#!/usr/bin/env bash
# Prints the SHA-256 checksum that GitHub holds for one file of an ffmpeg-for-homebridge release.
#
# Usage: ffmpeg-checksum.sh <release tag, for example v2.2.2> <aarch64|arm32v7>
#
# The image build downloads that file inside the image and unpacks it into / as root. The build
# passes this checksum in, and the download is only unpacked when it matches.
# The checksum comes from the GitHub API, so it protects against a broken or changed download.
# It can not protect against a bad file that was uploaded to the release itself.
#
# Uses GH_TOKEN when it is set (GitHub allows only a few requests per hour without one).
set -euo pipefail

TAG="${1:?usage: ffmpeg-checksum.sh <release tag> <aarch64|arm32v7>}"
ARCH="${2:?usage: ffmpeg-checksum.sh <release tag> <aarch64|arm32v7>}"

if ! [[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "ffmpeg-checksum.sh: not a release tag: ${TAG}" >&2
  exit 1
fi

case "$ARCH" in
  aarch64 | arm32v7) ;;
  *) echo "ffmpeg-checksum.sh: the architecture must be aarch64 or arm32v7" >&2; exit 1 ;;
esac

HEADERS=(-H "Accept: application/vnd.github+json")
[ -n "${GH_TOKEN:-}" ] && HEADERS+=(-H "Authorization: Bearer ${GH_TOKEN}")

RELEASE="$(curl -sSfL "${HEADERS[@]}" "https://api.github.com/repos/homebridge/ffmpeg-for-homebridge/releases/tags/${TAG}")"

CHECKSUM="$(jq -r --arg name "ffmpeg-alpine-${ARCH}.tar.gz" '.assets[] | select(.name == $name) | .digest // empty' <<< "$RELEASE" | sed -n 's/^sha256:\([0-9a-f]\{64\}\)$/\1/p' | head -n 1)"

if [ -z "$CHECKSUM" ]; then
  echo "ffmpeg-checksum.sh: no SHA-256 checksum found for ffmpeg-alpine-${ARCH}.tar.gz in release ${TAG}" >&2
  exit 1
fi

echo "$CHECKSUM"
