#!/usr/bin/env bash
# Rules for the build step that installs Homebridge (stage3_homebridge/01-homebridge/00-run.sh).
. "$(dirname "$0")/lib.sh"

RUN="$REPO/stage3_homebridge/01-homebridge/00-run.sh"

# The homebridge user runs every plugin. It may shut down and reboot the Pi (the sudo rule file),
# and nothing more.
isnt "the homebridge user is not added to the sudo group" grep -E 'usermod .*sudo|adduser .*sudo|gpasswd .*sudo' "$RUN"
has "the sudo rule file for shutdown and reboot is installed" "$RUN" 'install -m 0440 files/010_homebridge-nopasswd'
same "the sudo rule only names shutdown, reboot and poweroff" \
  "$(grep -v '^#' "$FILES/010_homebridge-nopasswd" | sed 's/.*NOPASSWD: //' | tr ',' '\n' | sed 's#.*/##; s/ //g' | sort -u | tr '\n' ' ')" \
  "poweroff reboot shutdown "

finish
