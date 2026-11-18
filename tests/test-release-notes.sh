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
echo '| Homebridge | 2.5.0 |' > output/homebridge_raspbian_image_arm64.manifest

PATH="$W/bin:$PATH" bash scripts/create-release-body.sh stable > "$W/log" 2>&1
same "the script runs to the end" "$?" "0"

BODY="$G/output/release-body.md"
has "compares the apt package with the previous release (v1.0.10)" "$BODY" "Updated from 2.0.3 to 2.0.4"
hasnt "does not compare with the release before that one" "$BODY" "Updated from 2.0.2"
has "asks for the manifest of the previous release" "$W/calls.log" "release download v1.0.10"
has "lists the commit made since the previous release" "$BODY" "STABLE: apt package 2.0.4"
hasnt "does not list a commit that was already in the previous release" "$BODY" "STABLE: apt package 2.0.3"

finish
