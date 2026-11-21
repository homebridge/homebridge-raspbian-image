#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# Stage 3 (the workflow that makes the release) and the script that joins the Imager entries.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

COMBINE="$REPO/combine-rpi-imager-snipplet.py"

combine() {
  rm -rf "${W:?}/c" && mkdir -p "${W:?}/c"
  for name in "$@"; do echo "{\"os_list\":[{\"name\":\"$name\"}]}" > "$W/c/rpi-image-repo-$name.json"; done
  ( cd "$W/c" && python3 "$COMBINE" ) > "$W/combine.log" 2>&1
}
names() { jq -c '[.os_list[].name]' "$W/c/rpi-image-repo.json" 2> /dev/null; }

combine 32bit 64bit
same "joins both images, 32-bit first (the order of the list today)" "$(names)" '["32bit","64bit"]'
combine 64bit
same "works with the 64-bit image only" "$?:$(names)" '0:["64bit"]'
combine 32bit
same "works with the 32-bit image only" "$?:$(names)" '0:["32bit"]'
combine
isnt "stops when there is no image at all" test "$?" -eq 0
isnt "writes no list when there is no image" test -e "$W/c/rpi-image-repo.json"

STAGE3="$REPO/.github/workflows/release-stage-3_package_release.yml"
STAGE2="$REPO/.github/workflows/create_raspbian_pi-gen.yml"

has "Stage 3 checks the links against the release tag before the release is made" "$STAGE3" '../scripts/check-imager-json.py rpi-image-repo.json --tag "$RELEASE_TAG"'
is "that check comes before the release is created" bash -c "[ \"\$(grep -n 'check-imager-json.py rpi-image-repo.json' '$STAGE3' | head -n1 | cut -d: -f1)\" -lt \"\$(grep -n 'gh release create' '$STAGE3' | head -n1 | cut -d: -f1)\" ]"
has "Stage 3 puts the tag on the commit that was built" "$STAGE3" 'TARGET=(--target "$TARGET_SHA")'
has "Stage 2 tells Stage 3 which commit was built" "$STAGE2" 'target_sha=${{ github.sha }}'
has "Stage 2 starts Stage 3 on its own branch" "$STAGE2" 'ref: ${{ github.ref_name }}'
isnt "Stage 2 does not start Stage 3 on a fixed branch" grep -q -- '--ref latest' "$STAGE2"
has "Stage 2 waits for Stage 3 (so the next build sees the new tag)" "$STAGE2" "workflow-file: 'release-stage-3_package_release.yml'"
has "Stage 3 shows the run name, so Stage 2 can find the run" "$STAGE3" '${{ inputs.run_name }}'
has "Discord is only told when the Imager list was updated too" "$STAGE3" "needs.publish-to-registry.result == 'success'"

finish
