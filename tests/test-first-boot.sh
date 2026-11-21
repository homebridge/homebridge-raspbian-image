#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# The script that runs once at the first boot of a new image.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

fake systemctl 'exit 0'

# first_boot: runs the script with its paths moved into $W/root
first_boot() {
  rm -f "${W:?}/calls.log"
  sed -E "s#(^|[[:space:]=\"<>])/(etc|proc)/#\1$W/root/\2/#g" "$FILES/first-boot-homebridge" > "$W/first-boot"
  ( PATH="$W/bin:$PATH" dash "$W/first-boot" ) > "$W/first-boot.log" 2>&1
}

mkdir -p "$W/root/etc/wpa_supplicant" "$W/root/proc/device-tree"
cp "$FILES/issue" "$W/root/etc/issue"
printf 'Raspberry Pi 4 Model B Rev 1.5\0' > "$W/root/proc/device-tree/model"
# a WiFi network in the old config file must not turn the network services off
printf 'network={\n  ssid="Home"\n  psk="secret"\n}\n' > "$W/root/etc/wpa_supplicant/wpa_supplicant.conf"

first_boot
same "the script ends with code 0" "$?" "0"
same "the Pi model is added as line 2 of the login screen" "$(sed -n 2p "$W/root/etc/issue")" 'RPI Model: \e{yellow}Raspberry Pi 4 Model B Rev 1.5\e{reset}'
same "the script turns itself off, and touches no other service" "$(calls | tr '\n' ';')" "systemctl disable first-boot-homebridge;systemctl daemon-reload;"
isnt "NetworkManager is never turned off" grep -qE 'systemctl .*(NetworkManager|wifi-connect)' "$FILES/first-boot-homebridge"
isnt "dhcpcd (not part of the image) is never used" grep -q 'dhcpcd' "$FILES/first-boot-homebridge"
is "dash (the /bin/sh of a Pi) accepts the script" dash -n "$FILES/first-boot-homebridge"

rm "$W/root/proc/device-tree/model"
cp "$FILES/issue" "$W/root/etc/issue"
first_boot
is "with no model file the login screen is left as it is" cmp -s "$FILES/issue" "$W/root/etc/issue"

finish
