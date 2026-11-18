#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# Rules for the build step that installs Homebridge (stage3_homebridge/01-homebridge/00-run.sh).
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

RUN="$REPO/stage3_homebridge/01-homebridge/00-run.sh"

# run_stage [NAME=value ...]: runs 00-run.sh for real against an empty folder that stands in for
# the image. pi-gen's on_chroot (it runs lines inside the image) is replaced by a stand-in that
# only saves those lines to $W/chroot-script.
run_stage() {
  rm -rf "${W:?}/rootfs" "${W:?}/chroot-script"
  mkdir -p "$W/rootfs/etc/update-motd.d" "$W/rootfs/usr/local/sbin" "$W/rootfs/etc/systemd/system" "$W/rootfs/tmp" "$W/rootfs/home/pi"
  (
    cd "$REPO/stage3_homebridge/01-homebridge" || exit 1
    # shellcheck disable=SC2317  # called by the script under test
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

# file modes: programs can be run (755), text files can not (644), the sudo rule is root-only (440)
mode() { stat -c '%a' "$W/rootfs/$1"; }
same "hb-config is installed as a program" "$(mode usr/local/sbin/hb-config)" "755"
same "the first boot script is installed as a program" "$(mode usr/local/sbin/first-boot-homebridge)" "755"
same "the nginx port script is installed as a program" "$(mode etc/hb-service/homebridge/prestart.d/20-hb-nginx-check)" "755"
same "the login message scripts are installed as programs" "$(mode etc/update-motd.d/15-linux)$(mode etc/update-motd.d/20-homebridge)" "755755"
same "/etc/issue is installed as a text file" "$(mode etc/issue)" "644"
same "the first boot service file is installed as a text file" "$(mode etc/systemd/system/first-boot-homebridge.service)" "644"
same "the sudo rule file is readable by root only" "$(mode etc/sudoers.d/010_homebridge-nopasswd)" "440"
isnt "nothing is left in /tmp of the image" test -n "$(ls -A "$W/rootfs/tmp")"

# the nginx build step
rm -rf "${W:?}/nginx-root" && mkdir -p "${W:?}/nginx-root/etc/nginx/sites-available" "${W:?}/nginx-root/usr/share/nginx/html" "${W:?}/nginx-root/etc/systemd/system" "${W:?}/nginx-root/usr/local/sbin"
(
  cd "$REPO/stage3_homebridge/03-nginx" || exit 1
  # shellcheck disable=SC2317  # called by the script under test
  on_chroot() { cat > /dev/null; }
  export -f on_chroot
  ROOTFS_DIR="$W/nginx-root" bash -e ./01-run.sh
) > /dev/null 2>&1
same "the nginx build step runs" "$?" "0"
same "the certificate script is installed as a program" "$(stat -c '%a' "$W/nginx-root/usr/local/sbin/nginx-homebridge-self-signed-cert")" "755"
same "the nginx site config is installed as a text file" "$(stat -c '%a' "$W/nginx-root/etc/nginx/sites-available/homebridge.local")" "644"

# The lines that run inside the image are fed to a shell on its standard input. A command that
# reads its input would swallow the lines after it, and the build would still pass.
# Here the saved lines run with every path moved into the scratch folder, and with stand-ins for
# the commands. The stand-in for apt-get reads all of its input, like apt-get does when it asks
# a question. The last line of the script must still run.
for name in sudo usermod systemctl; do fake "$name" 'exit 0'; done
# curl writes the "downloaded" key to the file after -o
fake curl 'while [ $# -gt 1 ]; do [ "$1" = "-o" ] && echo "KEY" > "$2"; shift; done'
# gpg: "--show-keys" prints the fingerprint in $W/fingerprint, "--dearmor" passes its input on
echo "ACAA60814A7524504F07DE07DF5B0FE88C8F5D92" > "$W/fingerprint"
fake gpg "case \"\$*\" in *--show-keys*) echo \"pub:-:4096:1:DF5B0FE88C8F5D92:\"; echo \"fpr:::::::::\$(cat $W/fingerprint):\" ;; *) cat ;; esac"
fake apt-get 'cat > /dev/null'
sed -E "s#(^|[[:space:]=\">\[])/(etc|root|home|usr|tmp|var|opt)/#\\1$W/rootfs/\\2/#g" "$W/chroot-script" > "$W/chroot-script.moved"
mkdir -p "$W/rootfs/etc/apt/sources.list.d" "$W/rootfs/usr/share/keyrings" "$W/rootfs/root" "$W/rootfs/var/lib/homebridge"
touch "$W/rootfs/home/pi/.bashrc" "$W/rootfs/etc/nsswitch.conf"
isnt "the test moved every path into the scratch folder" grep -E '(^|[[:space:]=">\[])/(etc|root|home|usr|tmp|var|opt)/' <(sed "s#$W/rootfs/##g" "$W/chroot-script.moved")
rm -f "${W:?}/calls.log"
( cd "$W" && PATH="$W/bin:$PATH" bash -e < "$W/chroot-script.moved" ) > "$W/chroot.log" 2>&1
same "the lines for inside the image run to the end" "$?" "0"
has "apt-get install does not ask (-y)" "$W/calls.log" "apt-get install -y homebridge=2.0.26"
has "the lines after apt-get still run (the last line turns on the first boot service)" "$W/calls.log" "systemctl enable first-boot-homebridge"
is "the service settings file is written after apt-get" grep -q 'UIX_CAN_SHUTDOWN_RESTART_HOST=1' "$W/rootfs/etc/systemd/system/homebridge.service.d/override.conf"

# the key of the Homebridge package repo is only trusted when it is the known key
has "the build asks for the key over https" "$W/calls.log" "curl -sSfL https://repo.homebridge.io/KEY.gpg"
echo "0000000000000000000000000000000000000000" > "$W/fingerprint"
rm -f "${W:?}/calls.log" "${W:?}/rootfs/usr/share/keyrings/homebridge.gpg"
( cd "$W" && PATH="$W/bin:$PATH" bash -e < "$W/chroot-script.moved" ) > "$W/chroot.log" 2>&1
isnt "the build stops when the downloaded key is not the known Homebridge key" test "$?" -eq 0
isnt "an unknown key is not installed" test -e "$W/rootfs/usr/share/keyrings/homebridge.gpg"
isnt "nothing is installed with an unknown key" grep -q '^apt-get' "$W/calls.log"

for stage in "$REPO"/stage3_homebridge/*/*run.sh; do
  name="${stage#"$REPO/stage3_homebridge/"}"
  isnt "$name: no apt-get install without -y" grep -nE 'apt-get install( |$)' <(grep -vE 'apt-get install (-y|--yes)' "$stage")
done

finish
