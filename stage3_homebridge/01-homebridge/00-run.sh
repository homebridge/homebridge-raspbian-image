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

# todo - remove this when Node.js comes bundled with a working version of npm
# upgrade npm (v6.13.4 that comes with Node 12.16.1 has issues with git dependencies)
npm install -g npm

# install homebridge and homebridge-config-ui-x
npm install -g --unsafe-perm homebridge@latest homebridge-config-ui-x@latest

# setup homebridge using hb-service
hb-service install --user ${HOMEBRIDGE_USER_NAME}

# remove the default config.json that was created
rm -rf /var/lib/homebridge/config.json

# correct ownership
chown -R "${HOMEBRIDGE_USER_NAME}:${HOMEBRIDGE_USER_NAME}" /var/lib/homebridge

# empty motd
> /etc/motd

# make a symlink to the main config directory
[ -e "/home/${HOMEBRIDGE_USER_NAME}/.homebridge" ] || ln -fs /var/lib/homebridge "/home/${HOMEBRIDGE_USER_NAME}/.homebridge"
[ -e /root/.homebridge ] || ln -fs /var/lib/homebridge /root/.homebridge

# set ui port for use in motd message
echo "8581" > /etc/hb-ui-port

# prioritise dns over mdns
sed -i 's/files mdns4_minimal \[NOTFOUND=return\] dns/files dns mdns4_minimal \[NOTFOUND=return\]/' /etc/nsswitch.conf

systemctl daemon-reload
systemctl enable homebridge
EOF

