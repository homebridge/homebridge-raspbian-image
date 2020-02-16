#!/bin/bash -e 

#
# Install Homebridge and Homebridge Config UI X
#

#
# Copy service files
#
install -m 644 files/hb-check.service "${ROOTFS_DIR}/etc/systemd/system/"

#
# Executables Files
#
install -m 755 files/homebridge-config "${ROOTFS_DIR}/usr/local/sbin/"
install -m 755 files/hb-check "${ROOTFS_DIR}/usr/local/sbin/"

# Pre-start files
install -v -d "${ROOTFS_DIR}/etc/hb-service/homebridge/prestart.d"
install -m 755 files/20-hb-nginx-check "${ROOTFS_DIR}/etc/hb-service/homebridge/prestart.d/"

#
# MOTD
#
install -m 755 files/issue "${ROOTFS_DIR}/etc/issue"
install -m 755 files/motd-linux "${ROOTFS_DIR}/etc/update-motd.d/15-linux"
install -m 755 files/motd-homebridge "${ROOTFS_DIR}/etc/update-motd.d/20-homebridge"

on_chroot << EOF
# install homebridge and homebridge-config-ui-x
npm install -g --unsafe-perm homebridge@latest homebridge-config-ui-x@latest

# setup homebridge using hb-service
hb-service install --user homebridge

# remove the default config.json that was created
rm -rf /var/lib/homebridge/config.json

# correct ownership
chown -R homebridge:homebridge /var/lib/homebridge

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
systemctl enable hb-check
EOF

