#!/bin/bash -e 

#
# Install Homebridge and Homebridge Config UI X
#

#
# Executables Files
#
install -m 755 files/hb-config "${ROOTFS_DIR}/usr/local/sbin/"

# Pre-start files
install -v -d "${ROOTFS_DIR}/etc/hb-service/homebridge/prestart.d"
install -m 755 files/20-hb-nginx-check "${ROOTFS_DIR}/etc/hb-service/homebridge/prestart.d/"

#
# hb-arch-check service
# this service rebuilds the modules for armv6 if the SD card is inserted into a Raspberry Pi 1 / Zero W
#
install -m 644 files/hb-arch-check.service "${ROOTFS_DIR}/etc/systemd/system/"
install -m 755 files/hb-arch-check "${ROOTFS_DIR}/etc/hb-service/"

#
# MOTD
#
install -m 755 files/issue "${ROOTFS_DIR}/etc/issue"
install -m 755 files/motd-linux "${ROOTFS_DIR}/etc/update-motd.d/15-linux"
install -m 755 files/motd-homebridge "${ROOTFS_DIR}/etc/update-motd.d/20-homebridge"

#
# Set Version
#
echo "$BUILD_VERSION" > "${ROOTFS_DIR}/etc/hb-release"

on_chroot << EOF
# install homebridge and homebridge-config-ui-x
npm install -g --unsafe-perm homebridge@latest homebridge-config-ui-x@latest

# setup homebridge using hb-service
hb-service install --user pi

# remove the default config.json that was created
rm -rf /var/lib/homebridge/config.json

# correct ownership
chown -R pi:pi /var/lib/homebridge

# empty motd
> /etc/motd

# make a symlink to the main config directory
[ -e /home/pi/.homebridge ] || ln -fs /var/lib/homebridge /home/pi/.homebridge
[ -e /root/.homebridge ] || ln -fs /var/lib/homebridge /root/.homebridge

# store the build arch
echo "armv7l" > /etc/homebridge-arch

# set ui port for use in motd message
echo "8581" > /etc/hb-ui-port

systemctl daemon-reload
systemctl enable homebridge
systemctl enable hb-arch-check
EOF

