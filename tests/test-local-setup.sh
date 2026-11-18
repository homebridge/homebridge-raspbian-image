#!/usr/bin/env bash
# setup_local_test_environment.sh prepares a local build on a developer's machine.
. "$(dirname "$0")/lib.sh"

# the script works in its own folder, so it runs in a copy of the files it needs
setup() {
  rm -rf "$W/copy" "$W/calls.log"
  mkdir -p "$W/copy"
  cp -r "$REPO/config" "$REPO/stable" "$REPO/stage3_homebridge" "$REPO/scripts" "$REPO/setup_local_test_environment.sh" "$W/copy/"
  fake docker 'exit 0'
  # git clone makes the folder named last
  fake git 'for last in "$@"; do :; done; mkdir -p "$(basename "$last")"; touch "$(basename "$last")/config"'
  fake curl 'echo "{\"assets\":[{\"name\":\"ffmpeg-alpine-aarch64.tar.gz\",\"digest\":\"sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"},{\"name\":\"ffmpeg-alpine-arm32v7.tar.gz\",\"digest\":\"sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}]}"'
  ( cd "$W/copy" && PATH="$W/bin:$PATH" ./setup_local_test_environment.sh "$@" ) > "$W/setup.log" 2>&1
}

setup
same "the script runs to the end" "$?" "0"
same "the only Docker things it removes are pi-gen's work container and pi-gen's image" \
  "$(calls | grep '^docker' | tr '\n' ';')" "docker rm -v pigen_work;docker rmi pi-gen;"
isnt "it never asks Docker to remove everything unused" grep -qi 'prune' "$REPO/setup_local_test_environment.sh"
has "64-bit is the default: pi-gen's arm64 branch is used" "$W/calls.log" "--branch arm64 https://github.com/RPi-Distro/pi-gen"
is "the Homebridge stage is copied into pi-gen" test -f "$W/copy/pi-gen/stage3_homebridge/prerun.sh"
for name in HOMEBRIDGE_APT_PKG_VERSION FFMPEG_FOR_HOMEBRIDGE_VERSION FFMPEG_SHA256 WIFI_CONNECT_VERSION RELEASE_STREAM HB_IMAGE_VERSION HB_IMAGE_BITS; do
  is "the build config gets $name" grep -qE "^export $name=\".+\"$" "$W/copy/pi-gen/config"
done
has "the 64-bit ffmpeg checksum is used" "$W/copy/pi-gen/config" 'FFMPEG_SHA256="aaaaaaaa'

# every value a stage script insists on is one this script provides
for name in $(grep -rhoE '^: "\$\{[A-Z0-9_]+:\?' "$REPO/stage3_homebridge" | sed -E 's/^: "\$\{([A-Z0-9_]+).*/\1/' | sort -u); do
  is "the build config provides $name, which a stage script needs" grep -q "^export $name=" "$W/copy/pi-gen/config"
done

setup 32bit
has "32bit: pi-gen's master branch is used" "$W/calls.log" "--branch master https://github.com/RPi-Distro/pi-gen"
has "32bit: the 32-bit ffmpeg checksum is used" "$W/copy/pi-gen/config" 'FFMPEG_SHA256="bbbbbbbb'
has "32bit: the image type is 32bit" "$W/copy/pi-gen/config" 'HB_IMAGE_BITS="32bit"'

setup 128bit
isnt "an unknown image type stops the script" test "$?" -eq 0
same "and nothing in Docker is touched" "$(calls | grep -c '^docker')" "0"

finish
