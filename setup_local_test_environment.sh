#!/bin/bash
#
# Sets up a pi-gen checkout in ./pi-gen to build the image on your own machine.
#
# Usage: ./setup_local_test_environment.sh [64bit|32bit]      (default: 64bit)
#
# It needs docker, git, jq and curl. It does not build anything by itself: it prints the
# command to start the build at the end.

set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

BITS="${1:-64bit}"

# the same pi-gen branches as the build workflow (.github/workflows/create_raspbian_pi-gen.yml)
case "$BITS" in
  64bit)
    PIGEN_BRANCH="arm64"
    FFMPEG_ARCH="aarch64"
    ;;
  32bit)
    PIGEN_BRANCH="master"
    FFMPEG_ARCH="arm32v7"
    ;;
  *)
    echo "Usage: $0 [64bit|32bit]" >&2
    exit 1
    ;;
esac

# Remove what an earlier local build left behind: pi-gen's work container and pi-gen's image.
# Nothing else in Docker is touched.
docker rm -v pigen_work > /dev/null 2>&1 || true
docker rmi pi-gen > /dev/null 2>&1 || true

rm -rf pi-gen

git clone --depth 1 --branch "$PIGEN_BRANCH" https://github.com/RPi-Distro/pi-gen

echo
echo "Copying setup for use"
echo

cp -r config stable stage3_homebridge ./pi-gen

# the versions the image is built from: one NAME=value per line, no spaces in the values
# shellcheck disable=SC2046
export $(./scripts/package-versions.sh stable)
FFMPEG_SHA256="$(./scripts/ffmpeg-checksum.sh "$FFMPEG_FOR_HOMEBRIDGE_VERSION" "$FFMPEG_ARCH")"
RELEASE_STREAM="stable"
HB_IMAGE_VERSION="local-test-$(date +%Y%m%d)"
HB_IMAGE_BITS="$BITS"

{
  echo
  echo "export HOMEBRIDGE_APT_PKG_VERSION=\"$HOMEBRIDGE_APT_PKG_VERSION\""
  echo "export FFMPEG_FOR_HOMEBRIDGE_VERSION=\"$FFMPEG_FOR_HOMEBRIDGE_VERSION\""
  echo "export FFMPEG_SHA256=\"$FFMPEG_SHA256\""
  echo "export WIFI_CONNECT_VERSION=\"$WIFI_CONNECT_VERSION\""
  echo "export RELEASE_STREAM=\"$RELEASE_STREAM\""
  echo "export HB_IMAGE_VERSION=\"$HB_IMAGE_VERSION\""
  echo "export HB_IMAGE_BITS=\"$HB_IMAGE_BITS\""
} | tee -a ./pi-gen/config

echo
echo 'To build the image, run:'
echo
echo '  ./pi-gen/build-docker.sh'
echo
