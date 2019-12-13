#!/bin/bash -e 

#
# Install Homebridge and Homebridge Config UI X
#

#
# Copy service files
#

install -m 644 files/homebridge.service "${ROOTFS_DIR}/etc/systemd/system/"
install -m 644 files/homebridge-config-ui-x.service "${ROOTFS_DIR}/etc/systemd/system/"
install -m 644 files/hb-check.service "${ROOTFS_DIR}/etc/systemd/system/"
install -m 644 files/env "${ROOTFS_DIR}/etc/default/homebridge"

#
# Executables Files
#
install -m 644 files/homebridge-config "${ROOTFS_DIR}/usr/local/sbin/"
install -m 644 files/hb-check "${ROOTFS_DIR}/usr/local/sbin/"
install -m 644 files/hb-config-setup "${ROOTFS_DIR}/usr/local/sbin/"

#
# MOTD
#
install -m 644 files/issue "${ROOTFS_DIR}/etc/issue"
install -m 644 files/motd-linux "${ROOTFS_DIR}/etc/update-motd.d/15-linux"
install -m 644 files/motd-homebridge "${ROOTFS_DIR}/etc/update-motd.d/20-homebridge"

#
# Make homebridge config directory
#
install -v -d -o 1000 -g 1000 "${ROOTFS_DIR}/var/lib/homebridge"

on_chroot << EOF
# install homebridge and homebridge-config-ui-x
npm install -g --unsafe-perm homebridge homebridge-config-ui-x

# correct ownership
chown -R pi:pi /var/lib/homebridge

# make executable
chmod +x /usr/local/sbin/homebridge-config
chmod +x /usr/local/sbin/hb-check
chmod +x /usr/local/sbin/hb-config-setup

chmod +x /etc/update-motd.d/15-linux
chmod +x /etc/update-motd.d/20-homebridge

# empty motd
> /etc/motd

# make a symlink to the main config directory
[ -e /home/pi/.homebridge ] || ln -fs /var/lib/homebridge /home/pi/.homebridge

# store the build arch
echo "armv7l" > /etc/homebridge-arch

systemctl daemon-reload
systemctl enable homebridge
systemctl enable homebridge-config-ui-x
systemctl enable hb-check
EOF

