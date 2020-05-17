#!/bin/bash -e 

#
# Enable pigpio service
#

on_chroot << EOF
systemctl daemon-reload
systemctl enable pigpiod
EOF
