#!/bin/bash -e 


#
# Install ffmpeg
#

case "$ARCH" in
  arm64)
    FFMPEG_ARCH="aarch64"
    ;;
  armhf)
    FFMPEG_ARCH="arm32v7"
    ;;
  *)
    echo "Unsupported ARCH: $ARCH"
    exit 1
    ;;
esac

on_chroot << EOF
uname -a

set -e
set -x

wget -q "https://github.com/homebridge/ffmpeg-for-homebridge/releases/download/${FFMPEG_FOR_HOMEBRIDGE_VERSION}/ffmpeg-alpine-${FFMPEG_ARCH}.tar.gz"
tar xzf "ffmpeg-alpine-${FFMPEG_ARCH}.tar.gz" -C / --no-same-owner
rm -rf ffmpeg-alpine-${FFMPEG_ARCH}.tar.gzz

ffmpeg || exit 0
EOF

# https://github.com/homebridge/ffmpeg-for-homebridge/releases/download/v2.2.0/ffmpeg-alpine-aarch64.tar.gz

# https://github.com/homebridge/ffmpeg-for-homebridge/releases/v2.2.0/download/ffmpeg-alpine-aarch64.tar.gz