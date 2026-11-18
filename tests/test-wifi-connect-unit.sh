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

RUN="$REPO/stage3_homebridge/02-wifi-connect/01-run.sh"
has "the build makes the copy of Node.js, owned by root" "$RUN" 'install -o root -g root -m 755 /opt/homebridge/bin/node /opt/wifi-connect/bin/node'
has "the build gives /opt/wifi-connect to root" "$RUN" 'chown -R root:root /opt/wifi-connect'

finish
