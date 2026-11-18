#!/usr/bin/env bash
# The build step that installs ffmpeg unpacks a download into / as root.
. "$(dirname "$0")/lib.sh"

GOOD_SHA="$(printf 'the real archive\n' | sha256sum | cut -d' ' -f1)"

# run_stage [NAME=value ...]: runs 01-run.sh with a stand-in for on_chroot that saves the lines
# for inside the image to $W/chroot-script
run_stage() {
  rm -f "$W/chroot-script"
  (
    cd "$REPO/stage3_homebridge/05-ffmpeg" || exit 1
    on_chroot() { cat >> "$W/chroot-script"; }
    export -f on_chroot
    export W
    env ARCH=arm64 FFMPEG_FOR_HOMEBRIDGE_VERSION=v2.2.2 FFMPEG_SHA256="$GOOD_SHA" "$@" bash -e ./01-run.sh
  ) > "$W/stage.log" 2>&1
}

# inside: runs the saved lines with stand-ins for wget, tar and (unless $1 is "no-ffmpeg") ffmpeg
inside() {
  rm -rf "$W/calls.log" "$W/bin"
  mkdir -p "$W/bin"
  fake uname 'exit 0'
  # wget writes the "download" to the file after -O
  fake wget "while [ \$# -gt 1 ]; do [ \"\$1\" = \"-O\" ] && cat \"$W/archive\" > \"\$2\"; shift; done"
  fake tar 'exit 0'
  [ "${1:-}" = "no-ffmpeg" ] || fake ffmpeg 'echo "ffmpeg version 8.0"'
  # only the stand-ins and the basic tools are on the PATH, so a real ffmpeg on this machine is not found
  ( cd "$W" && PATH="$W/bin:/usr/bin:/bin" bash -e < "$W/chroot-script" ) > "$W/inside.log" 2>&1
}

printf 'the real archive\n' > "$W/archive"

run_stage
same "the build step runs" "$?" "0"
inside
same "a download with the expected checksum is installed" "$?" "0"
has "the 64-bit file of the given release is downloaded" "$W/calls.log" "https://github.com/homebridge/ffmpeg-for-homebridge/releases/download/v2.2.2/ffmpeg-alpine-aarch64.tar.gz"
has "the download is unpacked into /" "$W/calls.log" "-C / --no-same-owner"
has "ffmpeg is started once as a test" "$W/calls.log" "ffmpeg -version"

printf 'another archive\n' > "$W/archive"
inside
isnt "a download with another checksum stops the build" test "$?" -eq 0
isnt "a download with another checksum is not unpacked" grep -q '^tar ' "$W/calls.log"
printf 'the real archive\n' > "$W/archive"

inside no-ffmpeg
isnt "the build stops when ffmpeg is not there after the install" test "$?" -eq 0

run_stage ARCH=armhf
inside
has "the 32-bit file is downloaded for a 32-bit image" "$W/calls.log" "ffmpeg-alpine-arm32v7.tar.gz"

run_stage FFMPEG_SHA256=
isnt "the build step stops when no checksum is passed in" test "$?" -eq 0
run_stage ARCH=riscv64
isnt "the build step stops on an architecture it does not know" test "$?" -eq 0

# scripts/ffmpeg-checksum.sh with a stand-in for the GitHub API
CHECKSUM="$REPO/scripts/ffmpeg-checksum.sh"
rm -rf "$W/bin" && mkdir -p "$W/bin"
cat > "$W/api.json" <<JSON
{"assets": [
  {"name": "ffmpeg-alpine-aarch64.tar.gz", "digest": "sha256:$GOOD_SHA"},
  {"name": "ffmpeg-alpine-arm32v7.tar.gz", "digest": null},
  {"name": "ffmpeg-alpine-x86_64.tar.gz", "digest": "sha256:short"}
]}
JSON
fake curl "cat \"$W/api.json\""
same "the checksum helper prints the checksum of the asked file" "$(PATH="$W/bin:$PATH" "$CHECKSUM" v2.2.2 aarch64)" "$GOOD_SHA"
has "the checksum helper asks for the release with that tag" "$W/calls.log" "releases/tags/v2.2.2"
isnt "the checksum helper stops when GitHub has no checksum for the file" env PATH="$W/bin:$PATH" "$CHECKSUM" v2.2.2 arm32v7
isnt "the checksum helper stops on an architecture it does not know" env PATH="$W/bin:$PATH" "$CHECKSUM" v2.2.2 x86_64
isnt "the checksum helper stops on a tag with other characters" env PATH="$W/bin:$PATH" "$CHECKSUM" "v2.2.2/../x" aarch64
fake curl 'exit 22'
isnt "the checksum helper stops when the GitHub API can not be reached" env PATH="$W/bin:$PATH" "$CHECKSUM" v2.2.2 aarch64

finish
