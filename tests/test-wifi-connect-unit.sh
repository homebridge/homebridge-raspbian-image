#!/usr/bin/env bash
# The WiFi setup service: what it may hold up at boot, and what it runs.
. "$(dirname "$0")/lib.sh"

UNIT="$REPO/stage3_homebridge/02-wifi-connect/files/wifi-connect.service"

before="$(grep -E '^Before=' "$UNIT" | cut -d= -f2-)"
same "only nginx waits for the WiFi setup service (they share port 80)" "$before" "nginx.service"
isnt "Homebridge does not wait for the WiFi setup service" grep -E '^(Before|RequiredBy|WantedBy)=.*homebridge\.service' "$UNIT"
is "the service starts after NetworkManager" grep -qx 'After=NetworkManager.service' "$UNIT"

finish
