#!/bin/bash -e 


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

curl -Lsf "https://unofficial-builds.nodejs.org/download/release/$LTS/node-$LTS-linux-armv6l.tar.gz" | tar xzf - -C /usr/local --strip-components=1 --no-same-owner

node -v
npm -v
EOF
