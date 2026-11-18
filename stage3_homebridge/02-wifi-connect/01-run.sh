#!/bin/bash -e 

#
# Install @homebridge/wifi-connect
#
# The version is one exact version from stable/package.json, passed in by the build
# (see scripts/package-versions.sh). The build stops here when it is missing.
: "${WIFI_CONNECT_VERSION:?WIFI_CONNECT_VERSION is not set}"

install -m 644 files/wifi-connect.service "${ROOTFS_DIR}/etc/systemd/system/"
install -m 755 files/log-iface-events.sh "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/"
install -m 644 files/wifi-powersave-off.conf "${ROOTFS_DIR}/etc/NetworkManager/conf.d/"

on_chroot << EOF
set -e
set -x

# wifi-connect runs as root at every boot. It gets its own copy of Node.js, owned by root.
# /opt/homebridge/bin/node is handed to the service user by the homebridge package, so root
# must not run that one.
mkdir -p /opt/wifi-connect/bin
install -o root -g root -m 755 /opt/homebridge/bin/node /opt/wifi-connect/bin/node

# npm from the homebridge package does the install, into /opt/wifi-connect
export PATH="/opt/homebridge/bin:\$PATH"
export npm_config_prefix=/opt/wifi-connect

node -v
npm -v

npm install -g --ignore-scripts --no-audit --no-fund "@homebridge/wifi-connect@${WIFI_CONNECT_VERSION}" < /dev/null

# nothing in /opt/wifi-connect may be changed by another user, and no npm cache stays in the image
chown -R root:root /opt/wifi-connect
chmod -R go-w /opt/wifi-connect
rm -rf /root/.npm

/opt/wifi-connect/bin/node /opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect/main.js --version

systemctl daemon-reload
systemctl enable wifi-connect
systemctl enable NetworkManager
systemctl disable dnsmasq
systemctl disable hostapd
EOF
