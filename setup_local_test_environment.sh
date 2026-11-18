#! /bin/bash

set -e


docker system prune -a
docker volume prune

rm -rf pi-gen


# export ARCH=aarch64 # For arm64 (64-bit)
# export ARCH=arm32v7 # For armhf (32-bit)#

git clone https://github.com/RPi-Distro/pi-gen
cd pi-gen
git switch arm64
cd ..

echo
echo "Copying setup for use"
echo

cp -r config stable ./pi-gen
cp -r stage* ./pi-gen

export BUILD_VERSION="$(date +%Y%m%d)-HB Test"
# shellcheck disable=SC2046 # one NAME=value per line, no spaces in the values
export $(./scripts/package-versions.sh stable)
FFMPEG_SHA256="$(./scripts/ffmpeg-checksum.sh "$FFMPEG_FOR_HOMEBRIDGE_VERSION" aarch64)"
export FFMPEG_SHA256
export RELEASE_STREAM="stable"
export HB_IMAGE_VERSION="local-test-$(date +%Y%m%d)"
export HB_IMAGE_BITS="64bit"

echo -e "\nexport BUILD_VERSION=\"$BUILD_VERSION\"" | tee -a ./pi-gen/config
echo "export HOMEBRIDGE_APT_PKG_VERSION=\"$HOMEBRIDGE_APT_PKG_VERSION\"" | tee -a ./pi-gen/config
echo "export FFMPEG_FOR_HOMEBRIDGE_VERSION=\"$FFMPEG_FOR_HOMEBRIDGE_VERSION\"" | tee -a ./pi-gen/config
echo "export WIFI_CONNECT_VERSION=\"$WIFI_CONNECT_VERSION\"" | tee -a ./pi-gen/config
echo "export FFMPEG_SHA256=\"$FFMPEG_SHA256\"" | tee -a ./pi-gen/config
echo "export RELEASE_STREAM=\"$RELEASE_STREAM\"" | tee -a ./pi-gen/config
echo "export HB_IMAGE_VERSION=\"$HB_IMAGE_VERSION\"" | tee -a ./pi-gen/config
echo "export HB_IMAGE_BITS=\"$HB_IMAGE_BITS\"" | tee -a ./pi-gen/config

echo
echo 'To build the image, run:'
echo
echo '  docker rm -v pigen_work ; ./pi-gen/build-docker.sh'
echo
