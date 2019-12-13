#!/bin/bash -e

#
# Setup nginx
#

install -m 644 files/homebridge.local "${ROOTFS_DIR}/etc/nginx/sites-available/"
install -m 644 files/custom_502.html "${ROOTFS_DIR}/usr/share/nginx/html/"
install -m 644 files/status.json "${ROOTFS_DIR}/usr/share/nginx/html/"

on_chroot << EOF
rm -rf /etc/nginx/sites-enabled/default
rm -rf /etc/nginx/sites-available/default
ln -sf /etc/nginx/sites-available/homebridge.local /etc/nginx/sites-enabled/homebridge.local
systemctl enable nginx
nginx -t
EOF
