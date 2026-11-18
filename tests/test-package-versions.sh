#!/usr/bin/env bash
# The build must use exact, written-down versions of everything it installs.
. "$(dirname "$0")/lib.sh"

SCRIPT="$REPO/scripts/package-versions.sh"

out="$("$SCRIPT" stable)"
is "prints the apt package version" grep -qE '^HOMEBRIDGE_APT_PKG_VERSION=[0-9]+\.[0-9]+\.[0-9]+' <<< "$out"
is "prints the ffmpeg version with a leading v" grep -qE '^FFMPEG_FOR_HOMEBRIDGE_VERSION=v[0-9]+\.[0-9]+\.[0-9]+$' <<< "$out"
is "prints the wifi-connect version" grep -qE '^WIFI_CONNECT_VERSION=[0-9]+\.[0-9]+\.[0-9]+$' <<< "$out"

for bad in '^4.2.2' '~4.2.2' '*' 'latest' '4.2' '' '4.2.2 || 5' '>=4'; do
  jq --arg v "$bad" '.dependencies["@homebridge/wifi-connect"] = $v' "$REPO/stable/package.json" > "$W/package.json"
  isnt "stops on the version '$bad'" "$SCRIPT" "$W/package.json"
done

jq 'del(.dependencies["@homebridge/wifi-connect"])' "$REPO/stable/package.json" > "$W/package.json"
isnt "stops when a package is missing" "$SCRIPT" "$W/package.json"
isnt "stops on a name that is not a stream or a file" "$SCRIPT" "../etc"

RUN="$REPO/stage3_homebridge/02-wifi-connect/01-run.sh"
has "the build installs the wifi-connect version it was given" "$RUN" 'npm install -g --ignore-scripts --no-audit --no-fund "@homebridge/wifi-connect@${WIFI_CONNECT_VERSION}" < /dev/null'
has "the build stops when no wifi-connect version was given" "$RUN" ': "${WIFI_CONNECT_VERSION:?'
has "the build workflow hands the wifi-connect version to the build" "$REPO/.github/workflows/create_raspbian_pi-gen.yml" '--env WIFI_CONNECT_VERSION='

tracked="$(jq -r '.directories[] | select(.directory == "stable") | .packages[].name' "$REPO/.github/homebridge-dependency-bot-stable.json" | sort | tr '\n' ' ')"
used="$(jq -r '.dependencies | keys[]' "$REPO/stable/package.json" | sort | tr '\n' ' ')"
same "the dependency bot tracks every package in stable/package.json" "$tracked" "$used"

finish
