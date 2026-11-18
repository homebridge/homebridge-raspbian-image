#!/usr/bin/env bash
# Shared helpers for the tests in this folder.
#
# How the tests work:
#   - a test copies a file from the repo into a scratch folder,
#   - rewrites the system paths in it (/etc/..., /var/...) to the scratch folder,
#   - puts fake commands (systemctl, curl, apt-get ...) first on the PATH,
#   - runs it, and looks at the result.
# Nothing on the machine that runs the tests is changed. No root rights are needed.

set -u

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILES="$REPO/stage3_homebridge/01-homebridge/files"

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/bin"

CHECKS=0
FAILED=0

ok() {
  CHECKS=$((CHECKS + 1))
  printf '  ok    %s\n' "$1"
}

fail() {
  CHECKS=$((CHECKS + 1))
  FAILED=$((FAILED + 1))
  printf '  FAIL  %s\n' "$1"
  shift
  [ $# -gt 0 ] && printf '        %s\n' "$@"
  return 0
}

# is <text> <command...>: passes when the command succeeds
is() {
  local text="$1"
  shift
  if "$@" >/dev/null 2>&1; then ok "$text"; else fail "$text" "command failed: $*"; fi
}

# isnt <text> <command...>: passes when the command fails
isnt() {
  local text="$1"
  shift
  if "$@" >/dev/null 2>&1; then fail "$text" "command passed but must fail: $*"; else ok "$text"; fi
}

# same <text> <actual> <expected>
same() {
  if [ "$2" = "$3" ]; then ok "$1"; else fail "$1" "expected: $3" "actual:   $2"; fi
}

# has <text> <file> <fixed text that must be in the file>
has() {
  if grep -qF -- "$3" "$2"; then ok "$1"; else fail "$1" "not found in $2: $3"; fi
}

# hasnt <text> <file> <fixed text that must not be in the file>
hasnt() {
  if grep -qF -- "$3" "$2"; then fail "$1" "found in $2: $3"; else ok "$1"; fi
}

# fake <name> [shell lines]: makes a fake command. Every call is written to $W/calls.log as
# "<name> <arguments>". Extra shell lines can set the output and the exit code.
fake() {
  local name="$1"
  shift
  {
    printf '#!/bin/sh\n'
    printf 'echo "%s $*" >> "%s/calls.log"\n' "$name" "$W"
    [ $# -gt 0 ] && printf '%s\n' "$@"
  } > "$W/bin/$name"
  chmod +x "$W/bin/$name"
}

calls() {
  [ -f "$W/calls.log" ] && cat "$W/calls.log"
  return 0
}

# nginx_accepts <site config file>: runs nginx's own config check on a site file, with a
# throw-away certificate. Prints nginx's answer. Returns 0 when nginx accepts the file with no
# warning, 1 when it does not, and 2 when nginx is not installed.
nginx_accepts() {
  local dir nginx_bin
  nginx_bin="$(PATH=/usr/sbin:/usr/bin command -v nginx)" || return 2
  dir="$(mktemp -d "$W/nginx.XXXXXX")"
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 -subj /CN=test -keyout "$dir/key" -out "$dir/crt" 2> /dev/null
  sed -E -e "s#^([[:space:]]*ssl_certificate)[[:space:]].*;#\\1 $dir/crt;#" -e "s#^([[:space:]]*ssl_certificate_key)[[:space:]].*;#\\1 $dir/key;#" "$1" > "$dir/site"
  printf 'pid %s/pid;\nerror_log %s/error.log;\nevents {}\nhttp { access_log off; include %s/site; }\n' "$dir" "$dir" "$dir" > "$dir/nginx.conf"
  "$nginx_bin" -t -c "$dir/nginx.conf" > "$dir/answer" 2>&1
  local code=$?
  cat "$dir/answer"
  [ "$code" -eq 0 ] && ! grep -q '\[warn\]\|\[emerg\]' "$dir/answer"
}

# hb_config_functions <file>: writes the functions of hb-config (everything above its menu loop)
# to <file>, with the system paths moved into $W/root. Tests load that file in dash, the shell
# that runs hb-config on a Pi, and call one function at a time with fake commands on the PATH.
hb_config_functions() {
  mkdir -p "$W/root/usr/share/keyrings" "$W/root/etc/apt/sources.list.d" "$W/root/etc/nginx/sites-available" \
    "$W/root/usr/local/sbin" "$W/root/opt" "$W/root/etc/systemd/system" "$W/root/tmp"
  sed '/^# Everything else needs to be run as root/,$d' "$FILES/hb-config-new" \
    | sed -E "s#(^|[[:space:]=\">\[])/(etc|usr|opt|boot|proc)/#\\1$W/root/\\2/#g" > "$1"
}

# hb_config <shell lines>: runs the lines in dash with the hb-config functions loaded.
# whiptail is a stand-in that answers "yes" to every question, or "no" when WHIPTAIL_ANSWER=1.
hb_config() {
  hb_config_functions "$W/hb-config-functions"
  [ -x "$W/bin/whiptail" ] || fake whiptail 'exit "${WHIPTAIL_ANSWER:-0}"'
  [ -x "$W/bin/pstree" ] || fake pstree 'echo "systemd---sshd---bash"'
  ( cd "$W" && PATH="$W/bin:$PATH" TMPDIR="$W/root/tmp" dash -c ". '$W/hb-config-functions'; $1" ) > "$W/hb-config.log" 2>&1
}

finish() {
  if [ "$FAILED" -gt 0 ]; then
    printf '  %s of %s checks failed\n' "$FAILED" "$CHECKS"
    exit 1
  fi
  exit 0
}
