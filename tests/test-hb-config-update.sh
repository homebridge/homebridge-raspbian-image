#!/usr/bin/env bash
# hb-config -> "Update Homebridge" and "Restore Config" must not leave the Pi worse off when a
# step fails, for example with no network.
. "$(dirname "$0")/lib.sh"

KEYRING="$W/root/usr/share/keyrings/homebridge.gpg"
LIST="$W/root/etc/apt/sources.list.d/homebridge.list"

# fresh: an installed key, and the given channel in the apt source file
fresh() {
  rm -rf "$W/root" "$W/calls.log" "$W/bin"
  mkdir -p "$W/bin" "$W/root/usr/share/keyrings" "$W/root/etc/apt/sources.list.d"
  echo "OLD KEY" > "$KEYRING"
  echo "deb [signed-by=/usr/share/keyrings/homebridge.gpg] https://repo.homebridge.io ${1:-stable} main" > "$LIST"
  cp "$LIST" "$W/list.before"
  fake apt-get 'exit 0'
  fake gpg 'tr -d "\n"; echo " (converted)"'
  # curl writes the "downloaded" key to the file after -o
  fake curl 'while [ $# -gt 1 ]; do [ "$1" = "-o" ] && echo "NEW KEY" > "$2"; shift; done'
}
apt_calls() { calls | grep '^apt-get' | sed 's/^apt-get //' | tr '\n' ';'; }

fresh
hb_config do_homebridge_update
same "update: installs the new key" "$(cat "$KEYRING")" "NEW KEY (converted)"
same "update: updates the lists, then installs the package" "$(apt_calls)" "update --allow-releaseinfo-change;install -y homebridge;"

fresh beta
hb_config do_homebridge_update
is "update: a user on the beta channel stays on beta" grep -q 'https://repo.homebridge.io beta main' "$LIST"
fresh legacy
hb_config do_homebridge_update
is "update: a user on the legacy channel stays on legacy" grep -q 'https://repo.homebridge.io legacy main' "$LIST"
fresh 'stable; evil'
hb_config do_homebridge_update
is "update: a channel name it does not know becomes stable" grep -qx "deb \[signed-by=$KEYRING\] https://repo.homebridge.io stable main" "$LIST"

fresh beta
fake curl 'exit 6'      # no network
hb_config do_homebridge_update
same "update, no network: the key in use is not touched" "$(cat "$KEYRING")" "OLD KEY"
is "update, no network: the apt source file is not touched" cmp -s "$LIST" "$W/list.before"
same "update, no network: apt-get is not run" "$(apt_calls)" ""
has "update, no network: the user is told" "$W/calls.log" "could not be downloaded"

fresh
fake curl 'while [ $# -gt 1 ]; do [ "$1" = "-o" ] && : > "$2"; shift; done'   # an empty download
fake gpg 'cat'
hb_config do_homebridge_update
same "update, empty download: the key in use is not touched" "$(cat "$KEYRING")" "OLD KEY"

fresh
fake gpg 'exit 2'       # the download is not a key
hb_config do_homebridge_update
same "update, bad download: the key in use is not touched" "$(cat "$KEYRING")" "OLD KEY"

fresh
hb_config do_restore_config
same "restore: downloads the package first, then removes, then installs" "$(apt_calls)" \
  "update --allow-releaseinfo-change;install -y --download-only --reinstall homebridge;purge -y homebridge;install -y homebridge;"
has "restore: the question says what is deleted" "$W/calls.log" "all plugins and their settings"
has "restore: the question names the backups" "$W/calls.log" "the backups stored on this device"

fresh
WHIPTAIL_ANSWER=1 hb_config do_restore_config
same "restore, answer no: nothing is run" "$(apt_calls)" ""

fresh
fake curl 'exit 6'
hb_config do_restore_config
same "restore, no network: nothing is removed" "$(apt_calls)" ""
has "restore, no network: the user is told that nothing was deleted" "$W/calls.log" "Nothing was deleted"

fresh
fake apt-get 'case "$*" in *download-only*) exit 100 ;; esac; exit 0'
hb_config do_restore_config
same "restore, package download fails: nothing is removed" "$(apt_calls | grep -c purge)" "0"

fresh
fake pstree 'echo "systemd---hb-service---bash"'
hb_config do_restore_config
same "restore from the UI terminal: nothing is run" "$(apt_calls)" ""

finish
