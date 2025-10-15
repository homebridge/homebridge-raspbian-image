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
export HOMEBRIDGE_APT_PKG_VERSION=$(jq -r '.dependencies["@homebridge/homebridge-apt-pkg"]' ./stable/package.json | sed 's/\^//')
export FFMPEG_FOR_HOMEBRIDGE_VERSION=v$(jq -r '.dependencies["ffmpeg-for-homebridge"]' ./stable/package.json | sed 's/\^//')
export RELEASE_STREAM="stable"

echo -e "\nexport BUILD_VERSION=\"$BUILD_VERSION\"" | tee -a ./pi-gen/config
echo "export HOMEBRIDGE_APT_PKG_VERSION=\"$HOMEBRIDGE_APT_PKG_VERSION\"" | tee -a ./pi-gen/config
echo "export FFMPEG_FOR_HOMEBRIDGE_VERSION=\"$FFMPEG_FOR_HOMEBRIDGE_VERSION\"" | tee -a ./pi-gen/config
echo "export RELEASE_STREAM=\"$RELEASE_STREAM\"" | tee -a ./pi-gen/config

echo
echo 'To build the image, run:'
echo
echo '  docker rm -v pigen_work ; ./pi-gen/build-docker.sh'
echo
