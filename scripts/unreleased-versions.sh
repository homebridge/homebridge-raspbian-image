#!/usr/bin/env bash
# Prints "true" when <stream>/package.json differs from the copy in the newest release, else "false".
#
# Usage: unreleased-versions.sh [stream]     (default: stable)
#
# Why: the dependency bot writes new versions to the branch BEFORE the image is built. If that
# build fails, the bot finds nothing new on the next day. This check lets the daily run see that
# the versions on the branch were never released, so it builds again.
#
# Needs the full git history with tags (actions/checkout with fetch-depth: 0).
set -euo pipefail

STREAM="${1:-stable}"

if ! [[ "$STREAM" =~ ^[a-z]+$ ]]; then
  echo "unreleased-versions.sh: not a stream name: ${STREAM}" >&2
  exit 1
fi

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# the newest release tag of this stream (stable tags have no "beta" or "alpha" in the name)
if [ "$STREAM" = "stable" ]; then
  NEWEST_TAG="$(git tag -l 'v*' | grep -v -E '(beta|alpha)' | sort -V | tail -n 1 || true)"
else
  NEWEST_TAG="$(git tag -l 'v*' | grep -F -- "$STREAM" | sort -V | tail -n 1 || true)"
fi

if [ -z "$NEWEST_TAG" ]; then
  echo "unreleased-versions.sh: no release tag found for ${STREAM}" >&2
  echo "true"
  exit 0
fi

if git diff --quiet "$NEWEST_TAG" HEAD -- "${STREAM}/package.json"; then
  echo "false"
else
  echo "unreleased-versions.sh: ${STREAM}/package.json changed since ${NEWEST_TAG}" >&2
  echo "true"
fi
