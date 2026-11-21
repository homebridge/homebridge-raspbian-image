#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# What the hb-config tool of current images offers, and that it is a valid script for the shell
# that runs it.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

TOOL="$FILES/hb-config-new"

same "the tool is a /bin/sh script" "$(head -n 1 "$TOOL")" "#!/bin/sh"
same "the old tool is still a /bin/sh script (old images download it)" "$(head -n 1 "$FILES/hb-config")" "#!/bin/sh"
is "dash accepts the old tool" dash -n "$FILES/hb-config"
is "the old tool says at its top which images use it" grep -q 'THIS IS THE OLD hb-config TOOL' <(head -n 5 "$FILES/hb-config")
is "the tool says at its top which images use it" grep -q 'every image built since May 2022' <(head -n 5 "$TOOL")
same "the build installs the current tool, not the old one" "$(grep -c 'install -m 755 files/hb-config-new "${ROOTFS_DIR}/usr/local/sbin/hb-config"' "$REPO/stage3_homebridge/01-homebridge/00-run.sh")" "1"
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
# shellcheck disable=SC2013  # one function name per word
for fn in $(grep -oE '\) do_[a-z_]+ ;;' "$TOOL" | awk '{print $2}' | sort -u); do
  is "menu function $fn exists" grep -q "^${fn}() {" "$TOOL"
done

# The tool has a version, so "Update" never goes back to an older tool. When the file changed
# since the newest release, the version must have changed too. (Needs the release tags; a
# checkout without them skips this.)
NEWEST_TAG="$(git -C "$REPO" tag -l 'v*' 2> /dev/null | grep -v -E '(beta|alpha)' | sort -V | tail -n 1)"
RELATIVE="stage3_homebridge/01-homebridge/files/hb-config-new"
if [ -n "$NEWEST_TAG" ] && git -C "$REPO" cat-file -e "$NEWEST_TAG:$RELATIVE" 2> /dev/null; then
  if git -C "$REPO" diff --quiet "$NEWEST_TAG" -- "$RELATIVE"; then
    ok "the tool is the same as in $NEWEST_TAG"
  else
    released="$(git -C "$REPO" show "$NEWEST_TAG:$RELATIVE" | sed -n 's/^HB_CONFIG_VERSION="\(.*\)"$/\1/p')"
    current="$(sed -n 's/^HB_CONFIG_VERSION="\(.*\)"$/\1/p' "$TOOL")"
    isnt "the tool changed since $NEWEST_TAG, so its version changed too (was '${released:-none}', is '$current')" test "$released" = "$current"
  fi
else
  echo "  skip  no release tags in this checkout: the version bump check did not run"
fi

finish
