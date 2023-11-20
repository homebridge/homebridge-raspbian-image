#!/bin/bash -e 


#
# Install ffmpeg
#

on_chroot << EOF
uname -a

set -e
set -x
 
wget -q "https://github.com/homebridge/ffmpeg-for-homebridge/releases/latest/download/ffmpeg-alpine-arm32v7.tar.gz"
tar xzf "ffmpeg-alpine-arm32v7.tar.gz" -C / --no-same-owner
rm -rf ffmpeg-alpine-arm32v7.tar.gzz

ffmpeg || exit 0
EOF
