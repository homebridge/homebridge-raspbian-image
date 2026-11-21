#!/usr/bin/env bash
# shellcheck disable=SC2016  # single quotes are meant: that text must reach the script under test as it is
# hb-config -> "Update" brings the WiFi setup tool of an older image up to the wanted version.
# It runs as root and replaces a tool that root runs at every boot, so: only a download with the
# checksum npm lists is used, and any failure leaves the old tool in place.
# shellcheck source=lib.sh
. "$(dirname "$0")/lib.sh"

TOOL="$FILES/hb-config-new"
WANTED="$(sed -n 's/^WIFI_CONNECT_WANTED="\(.*\)"$/\1/p' "$TOOL")"
same "the tool brings older images to the wifi-connect version new images are built with" \
  "$WANTED" "$(jq -r '.dependencies["@homebridge/wifi-connect"]' "$REPO/stable/package.json")"

# the service file inside the tool must be the one the image build installs (comments aside)
sed -n "/^  cat > \/etc\/systemd\/system\/wifi-connect.service << 'UNIT'$/,/^UNIT$/p" "$TOOL" | sed '1d;$d' > "$W/unit-in-tool"
grep -v '^#' "$REPO/stage3_homebridge/02-wifi-connect/files/wifi-connect.service" | sed '/^$/N;/^\n$/D' > "$W/unit-in-image"
is "the service file in the tool is the one the image build installs" diff <(grep -v '^$' "$W/unit-in-tool") <(grep -v '^$' "$W/unit-in-image")

if [ "$(id -u)" -ne 0 ]; then
  echo "  skip  the update itself is only tested as root (it sets file owners)"
  finish
fi

R="$W/root"
DIR="$R/opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect"
URL="https://registry.npmjs.org/@homebridge/wifi-connect"

# a package file like the one on npm: package/main.js, package/package.json, package/node_modules/
make_package() {
  rm -rf "${W:?}/pkg" && mkdir -p "$W/pkg/package/node_modules/express"
  echo "{\"version\":\"$1\"}" > "$W/pkg/package/package.json"
  echo "// wifi-connect $1" > "$W/pkg/package/main.js"
  tar czf "$W/package.tgz" -C "$W/pkg" package
}

# fresh <installed version> <node version>: an image with that wifi-connect, and npm answering honestly
fresh() {
  rm -rf "${R:?}" "${W:?}/calls.log" "${W:?}/bin"
  mkdir -p "$W/bin" "$DIR" "$R/opt/homebridge/bin" "$R/opt/wifi-connect/bin" "$R/etc/systemd/system" "$R/tmp"
  echo "{\"version\":\"$1\"}" > "$DIR/package.json"
  echo "// old" > "$DIR/main.js"
  echo "old unit" > "$R/etc/systemd/system/wifi-connect.service"
  # node: "-v" prints its version; "<folder>/main.js --version" prints the version in that folder
  cat > "$R/opt/homebridge/bin/node" <<NODE
#!/bin/sh
[ "\$1" = "-v" ] && { echo "$2"; exit 0; }
[ "\$2" = "--version" ] && exec jq -r .version "\$(dirname "\$1")/package.json"
exit 1
NODE
  chmod 755 "$R/opt/homebridge/bin/node"
  chown -R 1000:1000 "$R/opt/homebridge"
  make_package "$WANTED"
  jq -n --arg url "$URL/-/wifi-connect-$WANTED.tgz" --arg sum "sha512-$(openssl dgst -sha512 -binary "$W/package.tgz" | base64 | tr -d '\n')" \
    '{dist: {tarball: $url, integrity: $sum}}' > "$W/meta.json"
  # curl: the version page gives meta.json, the package address gives package.tgz
  cat > "$W/bin/curl" <<CURL
#!/bin/sh
echo "curl \$*" >> "$W/calls.log"
out=""; url=""
while [ \$# -gt 0 ]; do case "\$1" in -o) out="\$2"; shift ;; https://*) url="\$1" ;; esac; shift; done
case "\$url" in
  $URL/$WANTED) [ -f "$W/meta.json" ] && cat "$W/meta.json" > "\$out" ;;
  *.tgz) [ -f "$W/package.tgz" ] && cat "$W/package.tgz" > "\$out" ;;
  *) exit 22 ;;
esac
CURL
  chmod +x "$W/bin/curl"
  fake systemctl 'exit 0'
}
installed() { jq -r .version "$DIR/package.json"; }
unchanged() {
  same "$1: the old tool stays" "$(installed):$(cat "$DIR/main.js")" "4.2.1:// old"
  same "$1: the old service file stays" "$(cat "$R/etc/systemd/system/wifi-connect.service")" "old unit"
  same "$1: nothing is left behind" "$(find "$R/tmp" "$R/opt/wifi-connect" -name 'tmp.*' -o -name '*.new' -o -name '*.old' | wc -l | tr -d ' ')" "0"
  has "$1: the user is told" "$W/calls.log" "was not updated"
}

fresh 4.2.1 v24.1.0
hb_config do_update_wifi_connect
same "an older tool is brought to the wanted version" "$(installed)" "$WANTED"
is "the bundled packages come with it" test -d "$DIR/node_modules/express"
same "the new tool belongs to root" "$(stat -c '%U:%G' "$DIR/main.js")" "root:root"
same "the tool gets its own copy of Node.js, owned by root" "$(stat -c '%U:%G %a' "$R/opt/wifi-connect/bin/node")" "root:root 755"
is "the new service file is written" grep -q "^ExecStart=$R/opt/wifi-connect/bin/node " "$R/etc/systemd/system/wifi-connect.service"
has "systemd is told about the new service file" "$W/calls.log" "systemctl daemon-reload"
has "the checksum page of exactly this version is asked for" "$W/calls.log" "$URL/$WANTED "
same "nothing is left behind" "$(find "$R/tmp" "$R/opt/wifi-connect" -name 'tmp.*' -o -name '*.new' -o -name '*.old' | wc -l | tr -d ' ')" "0"

fresh "$WANTED" v24.1.0
hb_config do_update_wifi_connect
same "a tool that is already at the wanted version: nothing is downloaded" "$(calls | grep -c '^curl')" "0"
fresh 4.3.0 v24.1.0
hb_config do_update_wifi_connect
same "a newer tool: nothing is downloaded" "$(calls | grep -c '^curl')" "0"

fresh 4.2.1 v24.1.0
echo "changed on the way" >> "$W/package.tgz"
hb_config do_update_wifi_connect
unchanged "a download with another checksum"

fresh 4.2.1 v24.1.0
jq '.dist.tarball = "https://example.invalid/wifi-connect-4.2.2.tgz"' "$W/meta.json" > "$W/meta.tmp" && mv "$W/meta.tmp" "$W/meta.json"
hb_config do_update_wifi_connect
unchanged "a download address that is not npm's"
isnt "a download address that is not npm's: it is not downloaded" grep -q 'example.invalid' "$W/calls.log"

fresh 4.2.1 v24.1.0
jq 'del(.dist.integrity)' "$W/meta.json" > "$W/meta.tmp" && mv "$W/meta.tmp" "$W/meta.json"
hb_config do_update_wifi_connect
unchanged "no checksum from npm"

fresh 4.2.1 v24.1.0
rm "$W/meta.json"
hb_config do_update_wifi_connect
unchanged "npm can not be reached"

fresh 4.2.1 v24.1.0
make_package 4.2.0      # the package says it is another version than asked for
jq --arg sum "sha512-$(openssl dgst -sha512 -binary "$W/package.tgz" | base64 | tr -d '\n')" '.dist.integrity = $sum' "$W/meta.json" > "$W/meta.tmp" && mv "$W/meta.tmp" "$W/meta.json"
hb_config do_update_wifi_connect
unchanged "a package that does not start as the wanted version"

fresh 4.2.1 v18.20.4
hb_config do_update_wifi_connect
same "Node.js older than 20: the old tool stays" "$(installed)" "4.2.1"
has "Node.js older than 20: the user is told to update Node.js first" "$W/calls.log" "needs Node.js 20 or newer"
same "Node.js older than 20: nothing is downloaded" "$(calls | grep -c '^curl')" "0"

rm -rf "${R:?}" "${W:?}/calls.log"
hb_config do_update_wifi_connect
same "a system without the WiFi setup tool: nothing happens" "$?:$(calls | grep -c .)" "0:0"

finish
