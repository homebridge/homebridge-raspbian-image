#!/bin/bash -e 

#
# Install @homebridge/wifi-connect
#
# The version is one exact version from stable/package.json, passed in by the build
# (see scripts/package-versions.sh). The build stops here when it is missing.
: "${WIFI_CONNECT_VERSION:?WIFI_CONNECT_VERSION is not set}"

apt-get update
apt-get install -y jq

export LTS="$(curl -s https://nodejs.org/dist/index.json | jq -r 'map(select(.lts))[0].version')"

install -m 644 files/wifi-connect.service "${ROOTFS_DIR}/etc/systemd/system/"
install -m 755 files/log-iface-events.sh "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/"
install -m 644 files/wifi-powersave-off.conf "${ROOTFS_DIR}/etc/NetworkManager/conf.d/"

on_chroot << EOF
echo "Installing Node.js for WiFi Connect $LTS..."

set -e
set -x

mkdir -p /opt/wifi-connect

#wget -q "https://unofficial-builds.nodejs.org/download/release/$LTS/node-$LTS-linux-armv6l.tar.gz"
#tar xzf "node-$LTS-linux-armv6l.tar.gz" -C /opt/wifi-connect --strip-components=1 --no-same-owner
#rm -rf node-$LTS-linux-armv6l.tar.gz

#exit 1

export PATH="/opt/homebridge/bin:$PATH"
export npm_config_prefix=/opt/wifi-connect

node -v
npm -v

npm install -g --ignore-scripts --no-audit --no-fund "@homebridge/wifi-connect@${WIFI_CONNECT_VERSION}"

systemctl daemon-reload
systemctl enable wifi-connect
systemctl enable NetworkManager
#systemctl disable dhcpcd
systemctl disable dnsmasq
systemctl disable hostapd
EOF

