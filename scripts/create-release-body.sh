#!/usr/bin/env bash
# Writes the notes of a release to output/release-body.md.
#
# Usage: create-release-body.sh [stream]     (default: stable)
#
# Stage 3 runs it once per release, with the manifests of all built images in output/.
# The notes hold, in this order:
#   - the manifest of each image (what is in it),
#   - the SHA-256 checksums of the download files (when IMAGER_JSON names rpi-image-repo.json),
#   - what changed since the previous release: package versions, manifest rows, commits.
#
# It runs BEFORE the tag of the new release is made, so the newest existing tag is the previous
# release.
#
# Optional values:
#   RELEASE_COMMIT  the commit the images were built from (default: HEAD)
#   IMAGER_JSON     path to the combined rpi-image-repo.json
#
# Needs: git with the full history and tags, jq, and gh with GH_TOKEN (to download the manifests
# of the previous release; the notes are still written when that fails).

set -euo pipefail

# how many changed manifest rows are shown per image before the list is cut
MAX_DIFF_LINES=20

log() { echo "[$(date +'%H:%M:%S')] $*" >&2; }
warn() { echo "[$(date +'%H:%M:%S')] WARN: $*" >&2; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

STREAM="${1:-stable}"
COMMIT="${RELEASE_COMMIT:-HEAD}"

if ! [[ "$STREAM" =~ ^[a-z]+$ ]]; then
  echo "create-release-body.sh: not a stream name: ${STREAM}" >&2
  exit 1
fi

OUTPUT_DIR="${REPO_ROOT}/output"
PREVIOUS_DIR="${REPO_ROOT}/.previous"
BODY="${OUTPUT_DIR}/release-body.md"
PACKAGE_JSON="${STREAM}/package.json"

mkdir -p "$OUTPUT_DIR"
rm -rf "$PREVIOUS_DIR"
mkdir -p "$PREVIOUS_DIR"

# the newest existing tag of this stream (stable tags have no "beta" or "alpha" in the name)
if [[ "$STREAM" == "stable" ]]; then
  LATEST_TAG="$(git tag -l 'v*' | grep -v -E '(beta|alpha)' | sort -V | tail -n 1 || true)"
else
  LATEST_TAG="$(git tag -l 'v*' | grep -F -- "$STREAM" | sort -V | tail -n 1 || true)"
fi

log "Previous release for stream '${STREAM}': ${LATEST_TAG:-none}"

# ---- the manifest of each image
manifests() {
  local manifest
  for manifest in "$OUTPUT_DIR"/*manifest; do
    [ -f "$manifest" ] || continue
    cat "$manifest"
    echo
  done
}

# ---- the checksums of the download files
checksums() {
  [ -n "${IMAGER_JSON:-}" ] && [ -f "$IMAGER_JSON" ] || return 0
  echo "## Checksums (SHA-256)"
  echo
  echo "| File | SHA-256 |"
  echo "|:-----|:--------|"
  jq -r '.os_list[] | "| `\(.url | split("/") | last)` | `\(.image_download_sha256)` |"' "$IMAGER_JSON"
  echo
  # shellcheck disable=SC2016  # the backticks are Markdown, not a command
  echo 'The checksum of the `.img` file inside each zip is in `rpi-image-repo.json` (`extract_sha256`).'
  echo
}

# ---- package versions that changed since the previous release
package_changes() {
  local name previous current lines=""

  if ! git show "${LATEST_TAG}:${PACKAGE_JSON}" > "$PREVIOUS_DIR/package.json" 2> /dev/null; then
    warn "No ${PACKAGE_JSON} in ${LATEST_TAG}"
    return 0
  fi
  git show "${COMMIT}:${PACKAGE_JSON}" > "$PREVIOUS_DIR/package.current.json"

  while read -r name; do
    previous="$(jq -r --arg name "$name" '.dependencies[$name] // "not included"' "$PREVIOUS_DIR/package.json")"
    current="$(jq -r --arg name "$name" '.dependencies[$name]' "$PREVIOUS_DIR/package.current.json")"
    if [ "$previous" != "$current" ]; then
      lines+="* **${name}**: Updated from ${previous} to ${current}"$'\n'
    fi
  done < <(jq -r '.dependencies | keys[]' "$PREVIOUS_DIR/package.current.json")

  if [ -n "$lines" ]; then
    echo "### Package Version Changes"
    echo
    printf '%s\n' "$lines"
  fi
}

# ---- manifest rows that changed since the previous release
manifest_changes() {
  local manifest name previous changed total

  if ! gh release download "$LATEST_TAG" --pattern "*.manifest" --clobber --dir "$PREVIOUS_DIR" >&2; then
    warn "The manifests of ${LATEST_TAG} could not be downloaded"
    return 0
  fi

  for manifest in "$OUTPUT_DIR"/*manifest; do
    [ -f "$manifest" ] || continue
    name="$(basename "$manifest")"
    previous="${PREVIOUS_DIR}/${name}"
    [ -f "$previous" ] || continue

    # the table rows that were added (+) or removed (-)
    changed="$(diff -u "$previous" "$manifest" | grep -E '^[+-]\|' | sort -k2 || true)"
    [ -n "$changed" ] || continue

    total="$(printf '%s\n' "$changed" | wc -l | tr -d ' ')"
    echo "### Changes in ${name}"
    echo
    echo '```diff'
    printf '%s\n' "$changed" | head -n "$MAX_DIFF_LINES"
    echo '```'
    if [ "$total" -gt "$MAX_DIFF_LINES" ]; then
      echo
      echo "(${MAX_DIFF_LINES} of ${total} changed lines are shown. The manifest files of both releases have them all.)"
    fi
    echo
  done
}

# ---- commits since the previous release
commit_changes() {
  local commits
  # shellcheck disable=SC2016  # the backticks are Markdown, not a command
  commits="$(git log --no-merges --format='* %s (`%h`)' "${LATEST_TAG}..${COMMIT}")"
  echo "### Homebridge Raspbian Image Changes"
  echo
  if [ -n "$commits" ]; then
    printf '%s\n' "$commits"
  else
    echo "* No new commits since ${LATEST_TAG}"
  fi
  echo
}

{
  manifests
  checksums

  if [ -n "$LATEST_TAG" ]; then
    echo "## Changes Since Previous Release (${LATEST_TAG})"
    echo
    package_changes
    manifest_changes
    commit_changes
  else
    echo "## Changes"
    echo
    echo "This is the first release of the ${STREAM} stream."
    echo
  fi
} > "$BODY"

log "Release notes written to ${BODY}"
