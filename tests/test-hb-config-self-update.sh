#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# hb-config -> "Update" replaces the tool itself, as root. It must only install a complete
# script from a release, and it must keep the old tool when anything is wrong.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

INSTALLED="$W/root/usr/local/sbin/hb-config"

# fresh <tag GitHub reports> <content the download gives>
fresh() {
  rm -rf "${W:?}/root" "${W:?}/calls.log" "${W:?}/bin"
  mkdir -p "$W/bin" "$W/root/usr/local/sbin" "$W/root/tmp"
  printf '#!/bin/sh\necho old tool\n' > "$INSTALLED"
  printf '%s' "$2" > "$W/download"
  # curl: the "newest release" question (-w) prints the page GitHub sends it to;
  # a download (-o <file>, without -w) writes the prepared content to the file
  cat > "$W/bin/curl" <<FAKE
#!/bin/sh
echo "curl \$*" >> "$W/calls.log"
case "\$*" in
  *url_effective*) [ -n "$1" ] && printf '%s' "https://github.com/homebridge/homebridge-raspbian-image/releases/tag/$1"; exit 0 ;;
esac
out=""
while [ \$# -gt 1 ]; do [ "\$1" = "-o" ] && out="\$2"; shift; done
[ -n "\$out" ] && cat "$W/download" > "\$out"
exit ${CURL_EXIT:-0}
FAKE
  chmod +x "$W/bin/curl"
}

GOOD=$'#!/bin/sh\necho new tool\n'

fresh v2.0.26 "$GOOD"
hb_config do_update
same "installs the downloaded tool" "$(cat "$INSTALLED")" "${GOOD%$'\n'}"
same "the installed tool can be run" "$(stat -c '%a' "$INSTALLED")" "755"
has "downloads from the newest release tag, not from the branch tip" "$W/calls.log" \
  "https://raw.githubusercontent.com/homebridge/homebridge-raspbian-image/v2.0.26/stage3_homebridge/01-homebridge/files/hb-config-new"
isnt "does not download from the branch" grep -q 'homebridge-raspbian-image/latest/' "$W/calls.log"
same "leaves no folder behind" "$(find "$W/root/tmp" -mindepth 1 | wc -l | tr -d ' ')" "0"

keeps_old() {
  local text="$1"
  hb_config do_update
  same "$text: the old tool stays" "$(cat "$INSTALLED")" $'#!/bin/sh\necho old tool'
  same "$text: no folder is left behind" "$(find "$W/root/tmp" -mindepth 1 | wc -l | tr -d ' ')" "0"
}

# a line that bash accepts and /bin/sh (dash) does not
fresh v2.0.26 $'#!/bin/sh\nfunction broken { echo x; }\nif [[ a == b ]]; then echo; fi\narr=(1 2)\n'
keeps_old "a script that only bash accepts"

fresh v2.0.26 $'#!/bin/sh\nif true; then\n  echo cut off in the middle\n'
keeps_old "a script that is cut off"

fresh v2.0.26 ''
keeps_old "an empty download"

fresh v2.0.26 $'<html><body>Not found</body></html>\n'
keeps_old "a web page in place of the script"

fresh v2.0.26 $'#!/bin/bash\necho a bash script\n'
keeps_old "a script for another shell"

fresh '' "$GOOD"
keeps_old "no release found"
isnt "no release found: nothing is downloaded" grep -q 'raw.githubusercontent.com' "$W/calls.log"

fresh 'v2.0.26/../../evil' "$GOOD"
keeps_old "a release tag with other characters"

CURL_EXIT=22 fresh v2.0.26 "$GOOD"
keeps_old "the download fails"

finish
