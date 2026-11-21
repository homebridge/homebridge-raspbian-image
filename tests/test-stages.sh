#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# The list of build stages. stage0, stage1 and stage2 come from pi-gen. The others are folders
# in this repo.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

WORKFLOW="$REPO/.github/workflows/create_raspbian_pi-gen.yml"

stages="$(sed -n 's/^ *stage-list: *//p' "$WORKFLOW")"
same "the build uses pi-gen's stages 0 to 2 and then the Homebridge stage" "$stages" "stage0 stage1 stage2 stage3_homebridge"

for stage in $stages; do
  case "$stage" in
    stage[0-5]) isnt "$stage comes from pi-gen, so this repo has no folder with that name" test -e "$REPO/$stage" ;;
    *) is "$stage is a folder in this repo" test -d "$REPO/$stage" ;;
  esac
done

same "the config file for local builds lists the same stages" "$(sed -n 's/^STAGE_LIST="\(.*\)"$/\1/p' "$REPO/config")" "$stages"

# This repo must not swap pi-gen's own files for copies. (It used to replace pi-gen's signing
# key file with an old copy. pi-gen's file has had the needed fix since September 2026.)
isnt "no stage writes into pi-gen's own folders" grep -rnE '\.\./pi-gen/|\.\./stage[0-5]/' "$REPO"/stage*/
same "this repo ships no copy of the Raspberry Pi signing key" "$(find "$REPO" -name 'raspberrypi.gpg' -not -path '*/.git/*' | wc -l | tr -d ' ')" "0"

finish
