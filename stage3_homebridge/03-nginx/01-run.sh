#!/bin/bash -e

#
# Setup nginx
#

install -m 644 files/homebridge.local "${ROOTFS_DIR}/etc/nginx/sites-available/"
install -m 644 files/custom_502.html "${ROOTFS_DIR}/usr/share/nginx/html/"
install -m 644 files/status.json "${ROOTFS_DIR}/usr/share/nginx/html/"
install -m 644 files/hb-nginx-self-signed-cert.service "${ROOTFS_DIR}/etc/systemd/system/"
install -m 644 files/hb-nginx-self-signed-cert "${ROOTFS_DIR}/usr/local/sbin/"

on_chroot << EOF
rm -rf /etc/nginx/sites-enabled/default
rm -rf /etc/nginx/sites-available/default
ln -sf /etc/nginx/sites-available/homebridge.local /etc/nginx/sites-enabled/homebridge.local

chmod +x /usr/local/sbin/hb-nginx-self-signed-cert

systemctl enable nginx
systemctl enable hb-nginx-self-signed-cert
EOF
