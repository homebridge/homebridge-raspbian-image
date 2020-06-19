#!/bin/bash -e 


#
# Install ffmpeg
#

on_chroot << EOF
uname -a

set -e
set -x

wget "https://github.com/homebridge/ffmpeg-for-homebridge/releases/latest/download/ffmpeg-raspbian-armv6l.tar.gz"
tar xzf "ffmpeg-raspbian-armv6l.tar.gz" -C / --no-same-owner
rm -rf ffmpeg-raspbian-armv6l.tar.gz

ffmpeg || exit 0
EOF
