#!/usr/bin/env bash
# Puts a new rpi-image-repo.json into a checkout of homebridge/homebridge.io and pushes it.
#
# Usage: publish-imager-json.sh <checkout of homebridge.io, branch source> <rpi-image-repo.json> <release tag>
#
# Raspberry Pi Imager reads https://homebridge.io/rpi-image-repo.json, and a push to the "source"
# branch of homebridge.io is a live deploy of the website. So this script changes that one file
# and nothing else. The workflow checks the file (scripts/check-imager-json.py) before it runs this.
set -euo pipefail

CHECKOUT="${1:?usage: publish-imager-json.sh <checkout> <rpi-image-repo.json> <release tag>}"
SOURCE_FILE="${2:?usage: publish-imager-json.sh <checkout> <rpi-image-repo.json> <release tag>}"
RELEASE_TAG="${3:?usage: publish-imager-json.sh <checkout> <rpi-image-repo.json> <release tag>}"

# where the website keeps the file (homebridge.io serves src/public/ at the top of the site)
TARGET="src/public/rpi-image-repo.json"

if [ ! -f "$CHECKOUT/$TARGET" ]; then
  echo "publish-imager-json.sh: $TARGET is not in the checkout. Is this homebridge.io on branch source?" >&2
  exit 1
fi

# never push something that is not JSON
jq -e '.os_list | length > 0' "$SOURCE_FILE" > /dev/null

cp "$SOURCE_FILE" "$CHECKOUT/$TARGET"

cd "$CHECKOUT"

if git diff --quiet -- "$TARGET"; then
  echo "publish-imager-json.sh: $TARGET is already up to date, nothing to push"
  exit 0
fi

git -c user.name='github-actions[bot]' -c user.email='github-actions[bot]@users.noreply.github.com' \
  commit --quiet -m "New Homebridge Raspbian Image Release ${RELEASE_TAG}" -- "$TARGET"
git push --quiet origin HEAD

echo "publish-imager-json.sh: pushed $TARGET for ${RELEASE_TAG}"
