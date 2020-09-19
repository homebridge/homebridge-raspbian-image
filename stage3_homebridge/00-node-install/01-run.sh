#!/bin/bash -e 


#
# Prevent Node.js being installed or updated later using apt
#
install -m 644 files/apt-preferences "${ROOTFS_DIR}/etc/apt/preferences"

#
# Install Node.js
# Select the correct version of Node based on dpkg-architecture
#

export LTS="$(curl -s https://nodejs.org/dist/index.json | jq -r 'map(select(.lts))[0].version')"

on_chroot << EOF
uname -a

echo "Installing Node.js $LTS..."

set -e
set -x

case "$(dpkg-architecture -q DEB_TARGET_ARCH)" in
arm64)
  curl -Lsf "https://nodejs.org/dist/$LTS/node-$LTS-linux-arm64.tar.xz" | \
    tar xJf - -C /usr/local --strip-components=1 --no-same-owner
  ;;
armhf)
  curl -Lsf "https://unofficial-builds.nodejs.org/download/release/$LTS/node-$LTS-linux-armv6l.tar.gz" | \
    tar xzf - -C /usr/local --strip-components=1 --no-same-owner
  ;;
esac

node -v
npm -v
EOF
