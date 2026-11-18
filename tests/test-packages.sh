#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# The package lists of the Homebridge stage.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# the names in a package list, with comments taken out the way pi-gen does it
packages() { sed -e 's/#.*//' "$1" | tr -s '[:space:]' '\n' | sed '/^$/d' | sort; }

HB="$(packages "$REPO/stage3_homebridge/01-homebridge/00-packages")"
WIFI="$(packages "$REPO/stage3_homebridge/02-wifi-connect/00-packages")"

for name in ca-certificates curl gpg jq gcc g++ make git python3-pip ntpsec libavahi-compat-libdnssd-dev; do
  is "the Homebridge stage installs $name" grep -qxF -- "$name" <<< "$HB"
done
for name in apt-transport-https gnupg-agent; do
  isnt "the Homebridge stage does not install the empty hand-over package $name" grep -qxF -- "$name" <<< "$HB"
done
for name in network-manager wpasupplicant dnsmasq hostapd; do
  is "the WiFi stage installs $name" grep -qxF -- "$name" <<< "$WIFI"
done

# every command the build runs inside the image must come from a listed package or the base system
is "gpg (used for the package repo key) is installed by name" grep -qx 'gpg' <<< "$HB"

for list in "$REPO"/stage3_homebridge/*/00-packages; do
  isnt "${list#"$REPO/"}: every line is a package name or a comment" grep -nvE '^[[:space:]]*(#.*)?$|^[a-z0-9][a-z0-9+.-]+[[:space:]]*(#.*)?$' "$list"
done

finish
