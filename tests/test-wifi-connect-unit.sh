#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# The WiFi setup service: what it may hold up at boot, and what it runs.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

UNIT="$REPO/stage3_homebridge/02-wifi-connect/files/wifi-connect.service"

before="$(grep -E '^Before=' "$UNIT" | cut -d= -f2-)"
same "only nginx waits for the WiFi setup service (they share port 80)" "$before" "nginx.service"
isnt "Homebridge does not wait for the WiFi setup service" grep -E '^(Before|RequiredBy|WantedBy)=.*homebridge\.service' "$UNIT"
is "the service starts after NetworkManager" grep -qx 'After=NetworkManager.service' "$UNIT"

# A service that runs as root must not use files that the Homebridge service user can change.
# The homebridge package gives /opt/homebridge/bin (with node in it) and /var/lib/homebridge to that user.
for unit in "$REPO"/stage3_homebridge/*/files/*.service; do
  name="$(basename "$unit")"
  if grep -qE '^User=' "$unit"; then continue; fi
  grep -v '^[[:space:]]*#' "$unit" > "$W/unit"
  hasnt "$name (runs as root) does not use /opt/homebridge" "$W/unit" '/opt/homebridge'
  hasnt "$name (runs as root) does not use /var/lib/homebridge" "$W/unit" '/var/lib/homebridge'
done

path="$(grep -E '^Environment="PATH=' "$UNIT" | sed -e 's/^Environment="PATH=//' -e 's/"$//')"
same "the PATH of the WiFi setup service holds the system folders only" "$path" "/usr/sbin:/usr/bin:/sbin:/bin"
is "the service runs wifi-connect with its own copy of Node.js" grep -qx 'ExecStart=/opt/wifi-connect/bin/node /opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect/main.js' "$UNIT"

# The NetworkManager script that stops the setup hotspot when a network cable comes up.
DISPATCH="$REPO/stage3_homebridge/02-wifi-connect/files/50-wifi-connect-stop-on-cable"
mkdir -p "$W/sys/class/net/eth0/device" "$W/sys/class/net/enx001122334455/device" "$W/sys/class/net/wlan0/device" "$W/sys/class/net/veth12ab" "$W/sys/class/net/docker0"
sed "s#/sys/class/net/#$W/sys/class/net/#g" "$DISPATCH" > "$W/dispatch"
fake systemctl 'exit 0'
# nmcli answers with the kind of each device, the way NetworkManager names them
fake nmcli 'for last in "$@"; do :; done; case "$last" in eth0|enx*|veth*) echo ethernet ;; wlan0) echo wifi ;; docker0) echo bridge ;; esac'

# dispatch <device> <event>: prints "stopped" when the script stops wifi-connect
dispatch() {
  rm -f "${W:?}/calls.log"
  PATH="$W/bin:$PATH" dash "$W/dispatch" "$1" "$2" > /dev/null 2>&1
  if grep -q '^systemctl stop wifi-connect.service$' "$W/calls.log" 2> /dev/null; then echo stopped; else echo left; fi
}
same "a cable on eth0 coming up stops the setup hotspot" "$(dispatch eth0 up)" "stopped"
same "a USB network adapter with another name counts too" "$(dispatch enx001122334455 up)" "stopped"
same "WiFi coming up does not stop the service from outside" "$(dispatch wlan0 up)" "left"
same "a cable going down changes nothing" "$(dispatch eth0 down)" "left"
same "a virtual network card (Docker) is left out" "$(dispatch veth12ab up)" "left"
same "a bridge is left out" "$(dispatch docker0 up)" "left"
same "a device that does not exist is left out" "$(dispatch 'nosuch; reboot' up)" "left"
is "dash accepts the script" dash -n "$DISPATCH"

RUN="$REPO/stage3_homebridge/02-wifi-connect/01-run.sh"
has "the build installs the script for NetworkManager" "$RUN" 'install -m 755 files/50-wifi-connect-stop-on-cable "${ROOTFS_DIR}/etc/NetworkManager/dispatcher.d/"'
has "the build makes the copy of Node.js, owned by root" "$RUN" 'install -o root -g root -m 755 /opt/homebridge/bin/node /opt/wifi-connect/bin/node'
has "the build gives /opt/wifi-connect to root" "$RUN" 'chown -R root:root /opt/wifi-connect'

finish
