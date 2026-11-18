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

finish() {
  if [ "$FAILED" -gt 0 ]; then
    printf '  %s of %s checks failed\n' "$FAILED" "$CHECKS"
    exit 1
  fi
  exit 0
}
