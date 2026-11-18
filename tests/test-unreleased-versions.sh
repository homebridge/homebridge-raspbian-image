#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# After a failed image build, the next daily run must notice that the versions on the branch
# were never released.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

G="$W/repo"
mkdir -p "$G/scripts" "$G/stable"
cp "$REPO/scripts/unreleased-versions.sh" "$G/scripts/"
cd "$G" || exit 1
git init -q -b latest .
git config user.email test@example.invalid
git config user.name Test
commit() { git add -A && git commit -q -m "$1"; }

echo '{"dependencies":{"a":"1.0.0"}}' > stable/package.json
commit "first"
same "says true when there is no release yet" "$(./scripts/unreleased-versions.sh 2>/dev/null)" "true"

git tag v1.0.0
same "says false right after a release" "$(./scripts/unreleased-versions.sh 2>/dev/null)" "false"

echo "docs" > README.md
commit "other change"
same "says false when only other files changed" "$(./scripts/unreleased-versions.sh 2>/dev/null)" "false"

echo '{"dependencies":{"a":"1.0.1"}}' > stable/package.json
commit "bot: new version"
same "says true when a version changed and no release followed" "$(./scripts/unreleased-versions.sh 2>/dev/null)" "true"

git tag v1.0.1
git tag v1.0.2-beta.1 HEAD~1
git tag v1.0.10 HEAD
same "says false once that version is released (newest tag by number, beta tags left out)" "$(./scripts/unreleased-versions.sh 2>/dev/null)" "false"

isnt "stops on a stream name with other characters" ./scripts/unreleased-versions.sh "../x"

finish
