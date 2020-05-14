#!/bin/bash -e 


#
# Prevent Node.js being installed or updated later using apt
#
install -m 644 files/apt-preferences "${ROOTFS_DIR}/etc/apt/preferences"

#
# Install Node.js
# Installing the arm32v6 version of Node to ensure compilability with RaspberryPi 1 / Zero
#

export LTS="$(curl -s https://nodejs.org/dist/index.json | jq -r 'map(select(.lts))[0].version')"

on_chroot << EOF
uname -a

echo "Installing Node.js $LTS..."

set -e
set -x

wget "https://unofficial-builds.nodejs.org/download/release/$LTS/node-$LTS-linux-armv6l.tar.gz"
tar xzf "node-$LTS-linux-armv6l.tar.gz" -C /usr/local --strip-components=1 --no-same-owner
rm -rf node-$LTS-linux-armv6l.tar.gz

node -v
npm -v
EOF
