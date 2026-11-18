#!/usr/bin/env bash
# What the hb-config tool of current images offers, and that it is a valid script for the shell
# that runs it.
. "$(dirname "$0")/lib.sh"

TOOL="$FILES/hb-config-new"

same "the tool is a /bin/sh script" "$(head -n 1 "$TOOL")" "#!/bin/sh"
is "dash (the /bin/sh of a Pi) accepts the tool" dash -n "$TOOL"
hb_config ':'
same "the functions of the tool load in dash" "$?" "0"

# decided by BP, 2026-11-18: RaspBee, deCONZ and VNC are not offered any more
for word in deconz raspbee conbee phoscon vnc wiringpi; do
  isnt "the tool has no '$word' code" grep -qi "$word" "$TOOL"
done
isnt "the tool does not write to the old /boot/config.txt" grep -q '/boot/config.txt' "$TOOL"
isnt "the repo has no VNC uninstall script" test -e "$REPO/scripts/hb-config-vnc-uninstall"

hb_config_functions "$W/functions"
extra="$(sed -n '/^do_extra_packages() {/,/^}/p' "$W/functions")"
is "Extra Packages offers AdGuard Home" grep -q '"A0 AdGuard Home"' <<< "$extra"
is "Extra Packages offers Pi-hole" grep -q '"A1 Pi-hole"' <<< "$extra"
same "Extra Packages offers two entries" "$(grep -c '^    "A[0-9] ' <<< "$extra")" "2"

# every menu entry leads to a function that exists
for fn in $(grep -oE '\) do_[a-z_]+ ;;' "$TOOL" | awk '{print $2}' | sort -u); do
  is "menu function $fn exists" grep -q "^${fn}() {" "$TOOL"
done

finish
