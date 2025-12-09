#!/bin/bash -e 

#
# Install Homebridge and Homebridge Config UI X
#

#
# Executables Files
#
install -m 755 files/hb-config-new "${ROOTFS_DIR}/usr/local/sbin/hb-config"

# Pre-start files
install -v -d "${ROOTFS_DIR}/etc/hb-service/homebridge/prestart.d"
install -m 755 files/20-hb-nginx-check "${ROOTFS_DIR}/etc/hb-service/homebridge/prestart.d/"

# First boot service
install -m 644 files/first-boot-homebridge.service "${ROOTFS_DIR}/etc/systemd/system/"
install -m 755 files/first-boot-homebridge "${ROOTFS_DIR}/usr/local/sbin/"

# Sudoers configuration for homebridge user
install -v -d "${ROOTFS_DIR}/etc/sudoers.d"
install -m 0440 files/010_homebridge-nopasswd "${ROOTFS_DIR}/etc/sudoers.d/"

#
# MOTD
#
install -m 755 files/issue "${ROOTFS_DIR}/etc/issue"
install -m 755 files/motd-linux "${ROOTFS_DIR}/etc/update-motd.d/15-linux"
install -m 755 files/motd-homebridge "${ROOTFS_DIR}/etc/update-motd.d/20-homebridge"
install -m 633 files/bashrc.partial "${ROOTFS_DIR}/tmp/bashrc.partial"

export 

#
# Set Version
#
echo "$IMG_NAME" > "${ROOTFS_DIR}/etc/hb-release"

on_chroot << EOF

curl -sSfL https://repo.homebridge.io/KEY.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/homebridge.gpg  > /dev/null
echo "deb [signed-by=/usr/share/keyrings/homebridge.gpg] https://repo.homebridge.io ${RELEASE_STREAM} main" | tee /etc/apt/sources.list.d/homebridge.list > /dev/null

apt-get update
echo apt-get install homebridge=${HOMEBRIDGE_APT_PKG_VERSION}
apt-get install homebridge=${HOMEBRIDGE_APT_PKG_VERSION} 

# Add the homebridge user to the sudo group
usermod -aG sudo homebridge

mkdir -p /etc/systemd/system/homebridge.service.d
echo "[Service]" > /etc/systemd/system/homebridge.service.d/override.conf
echo "Environment=\"UIX_CAN_SHUTDOWN_RESTART_HOST=1\"" >> /etc/systemd/system/homebridge.service.d/override.conf
echo "Environment=\"UIX_STORAGE_PATH=/var/lib/homebridge\"" >> /etc/systemd/system/homebridge.service.d/override.conf

# correct ownership
# chown -R ${FIRST_USER_NAME}:${FIRST_USER_NAME} /var/lib/homebridge

# empty motd
> /etc/motd

# make a symlink to the main config directory
#[ -e /home/${FIRST_USER_NAME}/.homebridge ] || ln -fs /var/lib/homebridge /home/${FIRST_USER_NAME}/.homebridge
[ -e /root/.homebridge ] || ln -fs /var/lib/homebridge /root/.homebridge

# include homebridge bashrc in first user's bashrc
cat /tmp/bashrc.partial >> /home/${FIRST_USER_NAME}/.bashrc
rm -rf /tmp/bashrc.partial

# set ui port for use in motd message
echo "8581" > /etc/hb-ui-port

# prioritise dns over mdns
sed -i 's/files mdns4_minimal \[NOTFOUND=return\] dns/files dns mdns4_minimal \[NOTFOUND=return\]/' /etc/nsswitch.conf

systemctl daemon-reload
systemctl enable homebridge
systemctl enable first-boot-homebridge
EOF

