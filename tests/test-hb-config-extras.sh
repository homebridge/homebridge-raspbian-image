#!/usr/bin/env bash
# hb-config -> Extra Packages: downloads that root installs must not go through a file name that
# another user could prepare, and a failed download must not be installed.
. "$(dirname "$0")/lib.sh"

TOOL="$FILES/hb-config-new"

fresh() {
  rm -rf "$W/root" "$W/calls.log" "$W/bin"
  mkdir -p "$W/bin" "$W/root/tmp" "$W/root/opt"
  fake dpkg 'echo arm64'
  fake systemctl 'exit 0'
  fake hostname 'echo 192.168.1.10'
  # wget writes the "download" to the file after -O
  fake wget 'while [ $# -gt 1 ]; do [ "$1" = "-O" ] && echo archive > "$2"; shift; done'
  # tar "unpacks" a stand-in for the AdGuard Home program into the folder after -C
  fake tar "while [ \$# -gt 1 ]; do if [ \"\$1\" = \"-C\" ]; then mkdir -p \"\$2/AdGuardHome\"; printf '#!/bin/sh\necho \"AdGuardHome \$*\" >> \"$W/calls.log\"\n' > \"\$2/AdGuardHome/AdGuardHome\"; chmod +x \"\$2/AdGuardHome/AdGuardHome\"; fi; shift; done"
}

isnt "the tool uses no fixed file name in /tmp" grep -nE '(^|[^A-Za-z_"$])/tmp/' "$TOOL"

fresh
hb_config do_install_adguard_home
download="$(calls | sed -n 's/^wget -O \([^ ]*\) .*/\1/p')"
is "AdGuard Home: the download goes into a new folder with a random name" grep -qE "^$W/root/tmp/tmp\.[A-Za-z0-9]+/AdGuardHome.tar.gz$" <<< "$download"
has "AdGuard Home: the arm64 build is downloaded on a 64-bit system" "$W/calls.log" "AdGuardHome_linux_arm64.tar.gz"
has "AdGuard Home: that same file is unpacked" "$W/calls.log" "tar xf $download -C $W/root/opt/"
has "AdGuard Home: the program is installed as a service" "$W/calls.log" "AdGuardHome -s install"
isnt "AdGuard Home: the download folder is removed afterwards" test -e "$(dirname "$download")"

# another user made the old fixed folder and put a file in it: it must not be used
fresh
mkdir -p "$W/root/tmp/adguardhome" && echo planted > "$W/root/tmp/adguardhome/AdGuardHome_linux_arm64.tar.gz"
hb_config do_install_adguard_home
isnt "AdGuard Home: a file prepared in a fixed folder is not unpacked" grep -q 'tar .*adguardhome/' "$W/calls.log"

fresh
fake wget 'exit 4'
hb_config do_install_adguard_home
isnt "AdGuard Home, download fails: nothing is unpacked" grep -q '^tar ' "$W/calls.log"
isnt "AdGuard Home, download fails: nothing is installed" grep -q 'AdGuardHome -s install' "$W/calls.log"
has "AdGuard Home, download fails: the user is told" "$W/calls.log" "Nothing was installed"
same "AdGuard Home, download fails: no folder is left behind" "$(find "$W/root/tmp" -mindepth 1 | wc -l | tr -d ' ')" "0"

fresh
fake dpkg 'echo armhf'
hb_config do_install_adguard_home
has "AdGuard Home: the armv7 build is downloaded on a 32-bit system" "$W/calls.log" "AdGuardHome_linux_armv7.tar.gz"

fresh
mkdir -p "$W/root/etc/systemd/system" "$W/root/opt/AdGuardHome" && touch "$W/root/etc/systemd/system/AdGuardHome.service"
hb_config do_install_adguard_home
isnt "AdGuard Home, already installed: the uninstall removes the program" test -e "$W/root/opt/AdGuardHome"
isnt "AdGuard Home, already installed: nothing is downloaded" grep -q '^wget ' "$W/calls.log"

finish
