#!/bin/bash -e 

#
# Install balena-io/wifi-connect
#

install -m 644 files/wifi-connect.service "${ROOTFS_DIR}/etc/systemd/system/"
install -m 755 files/log-iface-events.sh "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/"
install -m 644 files/wifi-powersave-off.conf "${ROOTFS_DIR}/etc/NetworkManager/conf.d/"

on_chroot << EOF
set -x 

npm install -g @homebridge/wifi-connect

systemctl daemon-reload
systemctl enable wifi-connect
systemctl enable NetworkManager
systemctl disable dhcpcd
systemctl disable dnsmasq
systemctl disable hostapd
EOF

