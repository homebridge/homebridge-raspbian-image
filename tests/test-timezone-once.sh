#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# The timezone is looked up once, the first time the Pi has a network, and never when the user
# already picked one (decided by BP, 2026-11-18).
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

SCRIPT="$REPO/stage3_homebridge/04-tzupdate/files/60-hb-timezone-once"
R="$W/root"
DONE="$R/var/lib/hb-image/timezone-set-once"

# fresh <timezone the system has> <answer of the lookup | FAIL>
fresh() {
  rm -rf "${R:?}" "${W:?}/calls.log" "${W:?}/bin"
  mkdir -p "$W/bin" "$R/etc" "$R/run" "$R/var/lib/hb-image" "$R/usr/share/zoneinfo/Europe" "$R/usr/share/zoneinfo/America" "$R/usr/local/bin"
  touch "$R/usr/share/zoneinfo/Europe/London" "$R/usr/share/zoneinfo/Europe/Berlin" "$R/usr/share/zoneinfo/America/New_York"
  ln -s "$R/usr/share/zoneinfo/$1" "$R/etc/localtime"
  if [ "$2" = "FAIL" ]; then
    printf '#!/bin/sh\necho "tzupdate $*" >> "%s/calls.log"\nexit 1\n' "$W" > "$R/usr/local/bin/tzupdate"
  else
    printf '#!/bin/sh\necho "tzupdate $*" >> "%s/calls.log"\nprintf "%%s\\n" "%s"\n' "$W" "$2" > "$R/usr/local/bin/tzupdate"
  fi
  chmod +x "$R/usr/local/bin/tzupdate"
  fake timedatectl 'exit 0'
  sed -E "s#(^|[[:space:]=\"(])/(etc|run|var|usr)/#\1$R/\2/#g" "$SCRIPT" > "$W/timezone-once"
}
# event <device> <what happened>
event() { ( PATH="$W/bin:$PATH" dash "$W/timezone-once" "$1" "$2" ) > "$W/event.log" 2>&1; }
lookups() { calls | grep -c '^tzupdate' || true; }
sets() { calls | sed -n 's/^timedatectl set-timezone //p' | tr '\n' ' '; }

fresh Europe/London America/New_York
event eth0 up
same "first network connection: the timezone is looked up once" "$(lookups)" "1"
same "and set to the answer" "$(sets)" "America/New_York "
is "and it is written down that this is done" test -s "$DONE"
has "the lookup only prints the timezone, with a 10 second limit" "$W/calls.log" "tzupdate --print-only --timeout 10"

rm -f "${W:?}/calls.log"
event wlan0 up
event eth0 up
same "every later network connection: nothing is looked up or changed" "$(lookups):$(sets)" "0:"

fresh Europe/Berlin America/New_York
event eth0 up
same "a timezone the user picked: nothing is looked up" "$(lookups)" "0"
same "a timezone the user picked: it is not changed" "$(sets)" ""
is "a timezone the user picked: it is written down, so there is never a lookup later" test -s "$DONE"

fresh Europe/London FAIL
event eth0 up
same "no internet yet: nothing is changed" "$(sets)" ""
isnt "no internet yet: it is not written down as done" test -e "$DONE"
isnt "no internet yet: no lock is left behind" test -e "$R/run/hb-timezone-once.lock"
printf '#!/bin/sh\necho "tzupdate $*" >> "%s/calls.log"\necho Europe/Berlin\n' "$W" > "$R/usr/local/bin/tzupdate"
event eth0 up
same "the next network connection tries again and sets the timezone" "$(sets)" "Europe/Berlin "

for answer in '' 'Mars/Olympus_Mons' '../../etc/passwd' '/etc/passwd' 'Europe/London; reboot' 'Europe/Lon don' '$(reboot)'; do
  fresh Europe/London "$answer"
  event eth0 up
  same "an answer that is not a real timezone ('$answer') is not used" "$(sets)" ""
  isnt "and it is not written down as done ('$answer')" test -e "$DONE"
done

fresh Europe/London America/New_York
event eth0 down
event lo up
event eth0 pre-up
same "other events (down, the loopback device, pre-up) do nothing" "$(lookups)" "0"

fresh Europe/London America/New_York
mkdir "$R/run/hb-timezone-once.lock"
event eth0 up
same "a second copy does nothing while one is running" "$(lookups)" "0"

is "dash accepts the script" dash -n "$SCRIPT"

# the build step
RUN="$REPO/stage3_homebridge/04-tzupdate/00-run.sh"
is "the build installs one exact tzupdate version with its checksum" grep -qE 'tzupdate==\$\{TZUPDATE_VERSION\} --hash=sha256:\$\{TZUPDATE_SHA256\}' "$RUN"
has "pip must refuse a file with another checksum" "$RUN" "--require-hashes"
has "pip leaves no cache in the image" "$RUN" "--no-cache-dir"
isnt "no service runs tzupdate at every boot any more" grep -rq 'tzupdate.service\|systemctl enable tzupdate' "$REPO/stage3_homebridge"
same "the timezone in the script is the one the image is built with" \
  "$(sed -n 's/^IMAGE_TIMEZONE="\(.*\)"$/\1/p' "$SCRIPT")" \
  "$(sed -n 's/^ *timezone: *//p' "$REPO/.github/workflows/create_raspbian_pi-gen.yml")"
has "the README tells users about the one lookup" "$REPO/README.md" "looked up once"

finish
