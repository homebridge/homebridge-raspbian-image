#!/bin/bash -e

# Writes the manifest of the image: a small table with the versions of what is in it.
# The file is /opt/homebridge/homebridge_raspbian_image_<arch>.manifest in the image. The build
# workflow copies it out, checks it (scripts/check-image.sh) and adds it to the release.

: "${HB_IMAGE_VERSION:?HB_IMAGE_VERSION is not set}"
: "${HB_IMAGE_BITS:?HB_IMAGE_BITS is not set}"
: "${FFMPEG_FOR_HOMEBRIDGE_VERSION:?FFMPEG_FOR_HOMEBRIDGE_VERSION is not set}"
: "${HOMEBRIDGE_APT_PKG_VERSION:?HOMEBRIDGE_APT_PKG_VERSION is not set}"

# jq runs here in the build container (not inside the image), so it must be installed there
if ! command -v jq > /dev/null; then
  apt-get update
  apt-get install -y jq
fi

# The homebridge package brings its own manifest, with the versions of Node.js, Homebridge and
# the UI. Its table rows are copied into this manifest.
APT_MANIFEST_FILE=$(find "${ROOTFS_DIR}/opt/homebridge" -maxdepth 1 -name 'homebridge_apt_pkg*.manifest' | sort | head -n 1)
if [[ ! -f "$APT_MANIFEST_FILE" ]]; then
  echo "Manifest file not found: ${ROOTFS_DIR}/opt/homebridge/homebridge_apt_pkg*.manifest" >&2
  ls -l "${ROOTFS_DIR}/opt/homebridge/" >&2 || true
  exit 1
fi

# Keep only lines starting and ending with |, excluding the header lines
# (Windows line ends are taken off first, or no line would end with |)
APT_MANIFEST=$(sed 's/\r$//' "$APT_MANIFEST_FILE" | awk '/^\|.*\|$/ && !/Package/ && !/------/')
if [[ -z "$APT_MANIFEST" ]]; then
  echo "No table rows found in ${APT_MANIFEST_FILE}" >&2
  exit 1
fi

# WiFi connect is installed in /opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect/package.json
WIFI_CONNECT_INSTALLED=$(jq -r .version "${ROOTFS_DIR}/opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect/package.json")

MANIFEST_FILE="${ROOTFS_DIR}/opt/homebridge/homebridge_raspbian_image_${ARCH}.manifest"

cat > "$MANIFEST_FILE" << EOM
Homebridge Raspbian ${ARCH} Image Package Manifest

Release Version: ${HB_IMAGE_VERSION} (${HB_IMAGE_BITS})

| Package | Version |
|:-------:|:-------:|
| Debian | ${RELEASE} |
${APT_MANIFEST}
| ffmpeg for homebridge | ${FFMPEG_FOR_HOMEBRIDGE_VERSION} |
| Homebridge APT Package | ${HOMEBRIDGE_APT_PKG_VERSION} |
| WiFi Connect | ${WIFI_CONNECT_INSTALLED} |
EOM

chmod 644 "$MANIFEST_FILE"
cat "$MANIFEST_FILE"
