#!/bin/bash -e 


#
# Install ffmpeg
#

on_chroot << EOF
uname -a

set -e
set -x

case "$(dpkg-architecture -q DEB_TARGET_ARCH)" in
arm64)
  curl -Lsf "https://github.com/homebridge/ffmpeg-for-homebridge/releases/latest/download/ffmpeg-debian-aarch64.tar.gz" | \
    tar xzf - -C / --no-same-owner
  ;;
armhf)
  curl -Lsf  "https://github.com/homebridge/ffmpeg-for-homebridge/releases/latest/download/ffmpeg-raspbian-armv6l.tar.gz" | \
    tar xzf - -C / --no-same-owner
  ;;
esac

ffmpeg || exit 0
EOF
