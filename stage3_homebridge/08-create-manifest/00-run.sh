#!/bin/bash -e 

# Create the manifest.json file for Homebridge Raspbian Image


APT_MANIFEST_FILE=$(ls "${ROOTFS_DIR}/opt/homebridge/homebridge_apt_pkg"*.manifest 2>/dev/null | head -n 1)
if [[ -f "$APT_MANIFEST_FILE" ]]; then
    # Preserve all lines from the manifest file except header lines, keeping original line returns
    # Keep only lines starting and ending with |, excluding those containing Package or ------
    APT_MANIFEST=$(awk '/^\|.*\|$/ && !/Package/ && !/------/' "$APT_MANIFEST_FILE" | sed 's/\r$//')
else
    echo "Manifest file not found: ${ROOTFS_DIR}/opt/homebridge/homebridge_apt_pkg*.manifest"
    ls -l ${ROOTFS_DIR}/opt/homebridge/
fi

# WiFi connect is installed in /opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect/package.json
WIFI_CONNECT_VERSION=$(jq -r .version ${ROOTFS_DIR}/opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect/package.json)
on_chroot << EOF

MANIFEST_FILE="/opt/homebridge/homebridge_raspbian_image_${ARCH}.manifest"

cat <<EOM > "\${MANIFEST_FILE}"
Homebridge Raspbian ${ARCH} Image Package Manifest

Release Version: \${BUILD_VERSION//\"/}

| Package | Version |
|:-------:|:-------:|
| Debian | \${RELEASE} |
$( [[ -n "$APT_MANIFEST" ]] && echo "$APT_MANIFEST" )
| ffmpeg for homebridge | \${FFMPEG_FOR_HOMEBRIDGE_VERSION//\"/} |
| Homebridge APT Package | \${HOMEBRIDGE_APT_PKG_VERSION//\"/} |
| WiFi Connect | ${WIFI_CONNECT_VERSION} |
EOM
EOF