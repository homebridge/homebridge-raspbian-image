#!/usr/bin/env bash
# Runs every test in this folder. Usage: tests/run.sh [name-filter]
# Needs: bash, dash, jq, python3, git, GNU coreutils. Made to run on Linux (the CI runner or a
# Debian container).
set -u

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

failed=0
count=0

for test in test-*.sh; do
  [ -e "$test" ] || continue
  case "$test" in *"${1:-}"*) ;; *) continue ;; esac
  count=$((count + 1))
  printf '%s\n' "$test"
  if ! bash "./$test"; then
    failed=$((failed + 1))
  fi
done

printf '\n%s test files, %s failed\n' "$count" "$failed"
[ "$failed" -eq 0 ]
