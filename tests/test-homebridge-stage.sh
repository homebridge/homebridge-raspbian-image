#!/usr/bin/env bash
# Rules for the build step that installs Homebridge (stage3_homebridge/01-homebridge/00-run.sh).
. "$(dirname "$0")/lib.sh"

RUN="$REPO/stage3_homebridge/01-homebridge/00-run.sh"

# run_stage [NAME=value ...]: runs 00-run.sh for real against an empty folder that stands in for
# the image. pi-gen's on_chroot (it runs lines inside the image) is replaced by a stand-in that
# only saves those lines to $W/chroot-script.
run_stage() {
  rm -rf "$W/rootfs" "$W/chroot-script"
  mkdir -p "$W/rootfs/etc/update-motd.d" "$W/rootfs/usr/local/sbin" "$W/rootfs/etc/systemd/system" "$W/rootfs/tmp" "$W/rootfs/home/pi"
  (
    cd "$REPO/stage3_homebridge/01-homebridge" || exit 1
    on_chroot() { cat >> "$W/chroot-script"; }
    export -f on_chroot
    export W
    env ROOTFS_DIR="$W/rootfs" FIRST_USER_NAME=pi RELEASE_STREAM=stable HOMEBRIDGE_APT_PKG_VERSION=2.0.26 \
      HB_IMAGE_VERSION=v9.9.9 HB_IMAGE_BITS=64bit IMG_NAME=Homebridge-trixie-64bit "$@" bash -e ./00-run.sh
  ) > "$W/stage.log" 2>&1
}

run_stage
same "the build step runs to the end" "$?" "0"

# the image knows which release it is
same "/etc/hb-release holds the release tag and the image type" "$(cat "$W/rootfs/etc/hb-release")" "v9.9.9 (64bit)"
run_stage HB_IMAGE_VERSION=
isnt "the build step stops when no release tag is passed in" test "$?" -eq 0
run_stage

# The homebridge user runs every plugin. It may shut down and reboot the Pi (the sudo rule file),
# and nothing more.
isnt "the homebridge user is not added to the sudo group" grep -E 'usermod .*sudo|adduser .*sudo|gpasswd .*sudo' "$RUN"
has "the sudo rule file for shutdown and reboot is installed" "$RUN" 'install -m 0440 files/010_homebridge-nopasswd'
same "the sudo rule only names shutdown, reboot and poweroff" \
  "$(grep -v '^#' "$FILES/010_homebridge-nopasswd" | sed 's/.*NOPASSWD: //' | tr ',' '\n' | sed 's#.*/##; s/ //g' | sort -u | tr '\n' ' ')" \
  "poweroff reboot shutdown "

finish
