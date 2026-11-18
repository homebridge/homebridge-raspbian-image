#!/usr/bin/env bash
# The build step that writes the manifest of the image, and the values the build passes in.
. "$(dirname "$0")/lib.sh"

R="$W/rootfs"

# run_stage [NAME=value ...]: runs the step for real against a folder that stands in for the image
run_stage() {
  (
    cd "$REPO/stage3_homebridge/08-create-manifest" || exit 1
    env ROOTFS_DIR="$R" ARCH=arm64 RELEASE=trixie HB_IMAGE_VERSION=v9.9.9 HB_IMAGE_BITS=64bit \
      FFMPEG_FOR_HOMEBRIDGE_VERSION=v2.2.2 HOMEBRIDGE_APT_PKG_VERSION=2.0.26 "$@" bash -e ./00-run.sh
  ) > "$W/stage.log" 2>&1
}

fresh() {
  rm -rf "$R"
  mkdir -p "$R/opt/homebridge" "$R/opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect"
  echo '{"version":"4.2.2"}' > "$R/opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect/package.json"
  # the manifest of the homebridge package, in the form it has today (with Windows line ends, as a test)
  printf 'Homebridge Apt Package Manifest\r\n\r\n| Package | Version |\r\n|:-------:|:-------:|\r\n| NodeJS | v24.1.0 |\r\n| Homebridge UI | 5.30.1 |\r\n| Homebridge | 2.5.0 |\r\n' \
    > "$R/opt/homebridge/homebridge_apt_pkg_arm64.manifest"
}

fresh
run_stage
same "the step runs" "$?" "0"

cat > "$W/expected" <<'MANIFEST'
Homebridge Raspbian arm64 Image Package Manifest

Release Version: v9.9.9 (64bit)

| Package | Version |
|:-------:|:-------:|
| Debian | trixie |
| NodeJS | v24.1.0 |
| Homebridge UI | 5.30.1 |
| Homebridge | 2.5.0 |
| ffmpeg for homebridge | v2.2.2 |
| Homebridge APT Package | 2.0.26 |
| WiFi Connect | 4.2.2 |
MANIFEST
MADE="$R/opt/homebridge/homebridge_raspbian_image_arm64.manifest"
is "the manifest has the same table as before, and a plain release line" diff "$W/expected" "$MADE"
isnt "the manifest has no quote mark or backslash in it" grep -q '["\\]' "$MADE"
same "the manifest can be read by every user" "$(stat -c '%a' "$MADE")" "644"

# the image check reads the manifest: the two must agree on the row names
manifest_row() { awk -F'|' -v name="$1" '{ key = $2; gsub(/^ +| +$/, "", key); if (key == name) { value = $3; gsub(/^ +| +$/, "", value); print value } }' "$MADE"; }
for row in "NodeJS" "Homebridge" "Homebridge UI" "Homebridge APT Package" "ffmpeg for homebridge" "WiFi Connect"; do
  is "the row '$row' is one the image check looks for" grep -qF "manifest_has \"$row\"" "$REPO/scripts/check-image.sh"
  isnt "the row '$row' has a value" test -z "$(manifest_row "$row")"
done

fresh
rm "$R/opt/homebridge/homebridge_apt_pkg_arm64.manifest"
run_stage
isnt "the step stops when the manifest of the homebridge package is missing" test "$?" -eq 0
isnt "and writes no half manifest" test -e "$MADE"

fresh
printf 'no table here\n' > "$R/opt/homebridge/homebridge_apt_pkg_arm64.manifest"
run_stage
isnt "the step stops when the homebridge package manifest has no table" test "$?" -eq 0

fresh
run_stage HB_IMAGE_VERSION=
isnt "the step stops when no release tag is passed in" test "$?" -eq 0

# the values the build workflow passes to the stage scripts must be plain
WORKFLOW="$REPO/.github/workflows/create_raspbian_pi-gen.yml"
opts="$(sed -n '/^ *docker-opts: >-$/,/^$/p' "$WORKFLOW" | grep -- '--env')"
same "the workflow passes 7 values" "$(grep -c -- '--env' <<< "$opts")" "7"
isnt "no value has a quote mark, a backslash or a bracket around it" grep -E "[\"'\\\\]|\\\\\(|=\(" <(sed -e "s/\${{[^}]*}}/X/g" <<< "$opts")
isnt "no value holds a space" grep -E -- '--env [A-Z0-9_]+=[^ ]+ +[^ -]' <(sed -e "s/\${{[^}]*}}/X/g" <<< "$opts")
for name in $(grep -rhoE '^: "\$\{[A-Z0-9_]+:\?' "$REPO/stage3_homebridge" | sed -E 's/^: "\$\{([A-Z0-9_]+).*/\1/' | sort -u); do
  is "the workflow passes $name, which a stage script needs" grep -q -- "--env $name=" <<< "$opts"
done

finish
