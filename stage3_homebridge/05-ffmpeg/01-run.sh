#!/bin/bash -e

#
# Install ffmpeg
#
# The build passes in the release tag and the SHA-256 checksum of the file for this
# architecture (see scripts/ffmpeg-checksum.sh). The build stops here when one is missing.
: "${FFMPEG_FOR_HOMEBRIDGE_VERSION:?FFMPEG_FOR_HOMEBRIDGE_VERSION is not set}"
: "${FFMPEG_SHA256:?FFMPEG_SHA256 is not set}"

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

FFMPEG_TMP=\$(mktemp -d)
FFMPEG_FILE="\$FFMPEG_TMP/ffmpeg-alpine-${FFMPEG_ARCH}.tar.gz"

wget -q -O "\$FFMPEG_FILE" "https://github.com/homebridge/ffmpeg-for-homebridge/releases/download/${FFMPEG_FOR_HOMEBRIDGE_VERSION}/ffmpeg-alpine-${FFMPEG_ARCH}.tar.gz" < /dev/null

# the file is unpacked into / as root, so it is only used when its checksum is the expected one
echo "${FFMPEG_SHA256}  \$FFMPEG_FILE" | sha256sum -c -

tar xzf "\$FFMPEG_FILE" -C / --no-same-owner
rm -rf "\$FFMPEG_TMP"

# the build fails when ffmpeg is missing or does not run on this architecture
ffmpeg -version < /dev/null
EOF
