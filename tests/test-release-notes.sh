#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# The release notes must compare the new image with the release before it.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

# a small repo with three releases; the newest tag is v1.0.10 (not v1.0.9: tags sort by number)
G="$W/repo"
mkdir -p "$G/scripts" "$G/stable" "$G/output"
cp "$REPO/scripts/create-release-body.sh" "$G/scripts/"
cd "$G" || exit 1
git init -q -b latest .
git config user.email test@example.invalid
git config user.name Test
release() {
  jq -n --arg v "$1" '{dependencies: {"@homebridge/homebridge-apt-pkg": $v, "@homebridge/wifi-connect": "4.2.2", "ffmpeg-for-homebridge": "2.2.2"}}' > stable/package.json
  git add -A && git commit -q -m "STABLE: apt package $1"
  if [ -n "${2:-}" ]; then git tag "$2"; fi
}
release 2.0.1 v1.0.8
release 2.0.2 v1.0.9
git tag v1.0.11-beta.1
release 2.0.3 v1.0.10
release 2.0.4            # the commit that is being built; it has no tag yet

fake gh 'exit 1'         # no manifest of the previous release to download
cat > output/homebridge_raspbian_image_arm64.manifest <<'MANIFEST'
Homebridge Raspbian arm64 Image Package Manifest

Release Version: v1.0.11 (64bit)

| Package | Version |
|:-------:|:-------:|
| NodeJS | v24.2.0 |
| Homebridge | 2.5.0 |
MANIFEST
sed 's/arm64/armhf/; s/64bit/32bit/; s/v24.2.0/v22.9.0/' output/homebridge_raspbian_image_arm64.manifest > output/homebridge_raspbian_image_armhf.manifest

notes() { PATH="$W/bin:$PATH" "$@" bash scripts/create-release-body.sh stable > "$W/log" 2>&1; }

notes env
same "the script runs to the end" "$?" "0"

BODY="$G/output/release-body.md"
has "compares the apt package with the previous release (v1.0.10)" "$BODY" "Updated from 2.0.3 to 2.0.4"
hasnt "does not compare with the release before that one" "$BODY" "Updated from 2.0.2"
has "asks for the manifest of the previous release" "$W/calls.log" "release download v1.0.10"
has "lists the commit made since the previous release" "$BODY" "STABLE: apt package 2.0.4"
hasnt "does not list a commit that was already in the previous release" "$BODY" "STABLE: apt package 2.0.3"

# the notes are built once for both images: every part is there one time
count() { grep -cF -- "$1" "$BODY"; }
same "the 64-bit manifest is in the notes once" "$(count 'Homebridge Raspbian arm64 Image Package Manifest')" "1"
same "the 32-bit manifest is in the notes once" "$(count 'Homebridge Raspbian armhf Image Package Manifest')" "1"
same "the changes heading is there once" "$(count '## Changes Since Previous Release (v1.0.10)')" "1"
same "the package changes are there once" "$(count 'Updated from 2.0.3 to 2.0.4')" "1"
same "the commit list is there once" "$(count 'STABLE: apt package 2.0.4')" "1"
hasnt "the project name is spelled right" "$BODY" "Rasbian"
hasnt "no checksum table without the Imager list" "$BODY" "## Checksums"

# with the Imager list: the checksums of the download files are in the notes
cat > "$W/imager.json" <<'JSON'
{"os_list": [
  {"url": "https://github.com/homebridge/homebridge-raspbian-image/releases/download/v1.0.11/image_2026-11-19-Homebridge-trixie-32bit.zip", "image_download_sha256": "1111111111111111111111111111111111111111111111111111111111111111"},
  {"url": "https://github.com/homebridge/homebridge-raspbian-image/releases/download/v1.0.11/image_2026-11-19-Homebridge-trixie-64bit.zip", "image_download_sha256": "2222222222222222222222222222222222222222222222222222222222222222"}
]}
JSON
notes env IMAGER_JSON="$W/imager.json"
has "the notes list the checksum of the 64-bit download" "$BODY" '| `image_2026-11-19-Homebridge-trixie-64bit.zip` | `2222222222222222222222222222222222222222222222222222222222222222` |'
has "the notes list the checksum of the 32-bit download" "$BODY" '| `image_2026-11-19-Homebridge-trixie-32bit.zip` | `1111111111111111111111111111111111111111111111111111111111111111` |'

# with the manifests of the previous release: changed rows are shown, a long list is cut with a note
# gh "downloads" them into the folder after --dir
mkdir -p "$W/previous"
sed 's/v24.2.0/v24.1.0/' output/homebridge_raspbian_image_arm64.manifest > "$W/previous/homebridge_raspbian_image_arm64.manifest"
cp output/homebridge_raspbian_image_armhf.manifest "$W/previous/homebridge_raspbian_image_armhf.manifest"
fake gh "while [ \$# -gt 1 ]; do [ \"\$1\" = \"--dir\" ] && cp $W/previous/*.manifest \"\$2/\"; shift; done"
notes env
has "a changed manifest row is shown as removed" "$BODY" "-| NodeJS | v24.1.0 |"
has "and as added" "$BODY" "+| NodeJS | v24.2.0 |"
same "only the image with a change gets a changes section" "$(grep -c '^### Changes in ' "$BODY")" "1"

for i in $(seq 1 15); do echo "| package-$i | 2.0.0 |" >> output/homebridge_raspbian_image_arm64.manifest; echo "| package-$i | 1.0.0 |" >> "$W/previous/homebridge_raspbian_image_arm64.manifest"; done
notes env
has "a long list of changed rows is cut, and the notes say so" "$BODY" "(20 of 32 changed lines are shown."
same "20 changed rows are shown" "$(sed -n '/^```diff$/,/^```$/p' "$BODY" | grep -c '^[+-]|')" "20"

# the notes describe the commit that was built, not what was pushed after it
git commit -q --allow-empty -m "pushed after the build started"
notes env RELEASE_COMMIT=HEAD~1
hasnt "a commit made after the built commit is not in the notes" "$BODY" "pushed after the build started"
notes env
has "without a given commit the newest commit is used" "$BODY" "pushed after the build started"

finish
