#!/usr/bin/env bash
# Runs shellcheck on every shell script in this repo.
#
# Usage: scripts/lint.sh
#
# The one file left out is the old hb-config tool: no current image installs it, and it is left
# exactly as it is (see the note at its top).
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# every tracked file that starts with a shell "#!" line, plus every *.sh file
mapfile -t FILES < <(
  git ls-files | while read -r file; do
    [ -f "$file" ] || continue
    [ "$file" = "stage3_homebridge/01-homebridge/files/hb-config" ] && continue
    case "$file" in
      *.sh) echo "$file" ;;
      *) head -c 64 "$file" | head -n 1 | grep -qE '^#! ?/(usr/)?bin/(env )?(ba|da)?sh' && echo "$file" ;;
    esac
  done | sort -u
)

echo "shellcheck: ${#FILES[@]} files"
shellcheck --version | sed -n 2p
shellcheck -x "${FILES[@]}"
echo "shellcheck: no notes"
