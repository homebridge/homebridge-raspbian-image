#!/usr/bin/env bash
# Looks inside a finished image and checks that it is what a user needs.
#
# The build workflow runs this on the mounted image, before anything is released. If one check
# fails, the build fails, so no release is made and the Raspberry Pi Imager list is not touched.
#
# Usage:
#   check-image.sh <root folder of the image> --arch <arm64|armhf> --tag <v1.2.3>
#                  [--apt-pkg <version>] [--wifi-connect <version>] [--run] [--no-owner-check]
#
#   --run             also start programs from the image (needs root, and a machine that can run
#                     the image's programs)
#   --no-owner-check  skip the "owned by root" checks (for tests that do not run as root)
set -u

ROOT=""
ARCH=""
TAG=""
APT_PKG=""
WIFI_CONNECT=""
RUN=0
OWNER_CHECK=1

while [ $# -gt 0 ]; do
  case "$1" in
    --arch) ARCH="${2:-}"; shift 2 ;;
    --tag) TAG="${2:-}"; shift 2 ;;
    --apt-pkg) APT_PKG="${2:-}"; shift 2 ;;
    --wifi-connect) WIFI_CONNECT="${2:-}"; shift 2 ;;
    --run) RUN=1; shift ;;
    --no-owner-check) OWNER_CHECK=0; shift ;;
    -*) echo "check-image.sh: unknown option $1" >&2; exit 2 ;;
    *) ROOT="$1"; shift ;;
  esac
done

if [ -z "$ROOT" ] || [ ! -d "$ROOT" ] || [ -z "$TAG" ]; then
  echo "usage: check-image.sh <root folder> --arch <arm64|armhf> --tag <v1.2.3> [--apt-pkg <version>] [--wifi-connect <version>] [--run] [--no-owner-check]" >&2
  exit 2
fi

case "$ARCH" in
  arm64 | armhf) ;;
  *) echo "check-image.sh: --arch must be arm64 or armhf" >&2; exit 2 ;;
esac

FAILED=0

ok() { printf '  ok    %s\n' "$1"; }
bad() {
  FAILED=$((FAILED + 1))
  printf '  FAIL  %s\n' "$1"
}

# check <text> <command...>
check() {
  local text="$1"
  shift
  if "$@" >/dev/null 2>&1; then ok "$text"; else bad "$text"; fi
}

# The file mode as three or four digits, for example 755.
mode() { stat -c '%a' "$1" 2>/dev/null; }
has_mode() { [ "$(mode "$1")" = "$2" ]; }
is_program() { [ -f "$1" ] && [ -x "$1" ]; }

# A service that starts at boot has a link in multi-user.target.wants.
enabled() { [ -L "$ROOT/etc/systemd/system/multi-user.target.wants/$1" ]; }
not_enabled() { ! enabled "$1"; }

MANIFEST="$ROOT/opt/homebridge/homebridge_raspbian_image_${ARCH}.manifest"
WIFI_DIR="$ROOT/opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect"
WANTS="multi-user.target.wants"

# The version in one row of the manifest table, for example: manifest_version "NodeJS" -> v24.1.0
manifest_version() {
  awk -F'|' -v name="$1" '{ key = $2; gsub(/^ +| +$/, "", key); if (key == name) { value = $3; gsub(/^ +| +$/, "", value); print value } }' "$MANIFEST" 2>/dev/null | head -n 1
}
manifest_has() { [ -n "$(manifest_version "$1")" ]; }

# Runs "nginx -t" inside the image on the Homebridge site config. The certificate is made on the
# Pi at first boot, so a throw-away one is used for the check.
nginx_config_ok() {
  local result
  mkdir -p "$ROOT/tmp/hb-check"
  chroot "$ROOT" /bin/sh -e -s <<'CHECK'
cd /tmp/hb-check
openssl req -x509 -nodes -newkey rsa:2048 -days 1 -subj /CN=check -keyout key -out crt 2>/dev/null
sed -e 's#/etc/nginx/ssl/homebridge.local.crt#/tmp/hb-check/crt#' \
    -e 's#/etc/nginx/ssl/homebridge.local.key#/tmp/hb-check/key#' \
    /etc/nginx/sites-available/homebridge.local > site
printf 'pid /tmp/hb-check/pid;\nevents {}\nhttp { include /tmp/hb-check/site; }\n' > nginx.conf
nginx -t -c /tmp/hb-check/nginx.conf 2>&1 | tee result
# a warning (for example a setting nginx calls "deprecated") also fails the check
! grep -q '\[warn\]\|\[emerg\]' result
CHECK
  result=$?
  rm -rf "$ROOT/tmp/hb-check"
  return "$result"
}

echo "Homebridge"
check "Node.js is installed (/opt/homebridge/bin/node)" is_program "$ROOT/opt/homebridge/bin/node"
check "Homebridge is installed" test -f "$ROOT/var/lib/homebridge/node_modules/homebridge/package.json"
check "the Homebridge UI is installed" test -f "$ROOT/opt/homebridge/lib/node_modules/homebridge-config-ui-x/package.json"
check "hb-service is installed" test -e "$ROOT/opt/homebridge/hb-service-shim"
check "the homebridge service starts at boot" enabled homebridge.service
check "the service settings file is in place" grep -q 'UIX_CAN_SHUTDOWN_RESTART_HOST=1' "$ROOT/etc/systemd/system/homebridge.service.d/override.conf"
check "the service settings file does not change the service user" bash -c "! grep -q '^User=' '$ROOT/etc/systemd/system/homebridge.service.d/override.conf'"
check "the homebridge user exists" grep -q '^homebridge:' "$ROOT/etc/passwd"
check "the homebridge user is not in the sudo group" bash -c "! grep -E '^sudo:' '$ROOT/etc/group' | cut -d: -f4 | tr ',' '\n' | grep -qx homebridge"
check "the sudo rule for shutdown and reboot is in place, readable by root only" has_mode "$ROOT/etc/sudoers.d/010_homebridge-nopasswd" 440
if [ -n "$APT_PKG" ]; then
  check "the homebridge apt package is version ${APT_PKG}" bash -c "awk '/^Package: homebridge\$/ { found = 1 } found && /^Version: / { print \$2; exit }' '$ROOT/var/lib/dpkg/status' | grep -qxF '$APT_PKG'"
fi

echo "Image files"
check "/etc/hb-release is set" test -s "$ROOT/etc/hb-release"
check "/etc/hb-ui-port holds the default port" grep -qx '8581' "$ROOT/etc/hb-ui-port"
check "hb-config is installed" is_program "$ROOT/usr/local/sbin/hb-config"
check "the nginx port script is installed" is_program "$ROOT/etc/hb-service/homebridge/prestart.d/20-hb-nginx-check"
check "the first boot service starts at boot" enabled first-boot-homebridge.service
check "the first boot script is installed" is_program "$ROOT/usr/local/sbin/first-boot-homebridge"
check "ffmpeg is installed" is_program "$ROOT/usr/local/bin/ffmpeg"

echo "Manifest"
check "the manifest exists" test -s "$MANIFEST"
check "the manifest lists Node.js" manifest_has "NodeJS"
check "the manifest lists Homebridge" manifest_has "Homebridge"
check "the manifest lists the Homebridge UI" manifest_has "Homebridge UI"
check "the manifest lists the apt package" manifest_has "Homebridge APT Package"
check "the manifest lists ffmpeg" manifest_has "ffmpeg for homebridge"
check "the manifest lists wifi-connect" manifest_has "WiFi Connect"

echo "nginx"
check "nginx starts at boot" enabled nginx.service
check "the Homebridge site is turned on" test -L "$ROOT/etc/nginx/sites-enabled/homebridge.local"
check "the Homebridge site config is in place" grep -q 'proxy_pass' "$ROOT/etc/nginx/sites-available/homebridge.local"
check "the certificate service starts at boot" enabled nginx-homebridge-self-signed-cert.service
check "the certificate script is installed" is_program "$ROOT/usr/local/sbin/nginx-homebridge-self-signed-cert"
check "no certificate or key is part of the image" bash -c "! ls '$ROOT'/etc/nginx/ssl/* 2>/dev/null | grep -q ."

echo "WiFi setup"
check "the wifi-connect service starts at boot" enabled wifi-connect.service
check "wifi-connect is installed" test -f "$WIFI_DIR/main.js"
check "wifi-connect has its own copy of Node.js" is_program "$ROOT/opt/wifi-connect/bin/node"
check "the wifi-connect service does not use files from /opt/homebridge" bash -c "! grep -v '^[[:space:]]*#' '$ROOT/etc/systemd/system/wifi-connect.service' | grep -q '/opt/homebridge'"
check "the wifi-connect service does not hold up Homebridge" bash -c "! grep -E '^Before=' '$ROOT/etc/systemd/system/wifi-connect.service' | grep -q 'homebridge.service'"
if [ -n "$WIFI_CONNECT" ]; then
  check "wifi-connect is version ${WIFI_CONNECT}" bash -c "jq -r .version '$WIFI_DIR/package.json' | grep -qxF '$WIFI_CONNECT'"
fi
if [ "$OWNER_CHECK" -eq 1 ]; then
  check "everything in /opt/wifi-connect belongs to root" bash -c "[ -z \"\$(find '$ROOT/opt/wifi-connect' \\( ! -uid 0 -o ! -gid 0 \\) -print -quit)\" ]"
  check "nothing in /opt/wifi-connect can be changed by other users" bash -c "[ -z \"\$(find '$ROOT/opt/wifi-connect' ! -type l -perm /022 -print -quit)\" ]"
fi
check "NetworkManager starts at boot" enabled NetworkManager.service
check "dnsmasq does not start at boot (wifi-connect starts its own copy when needed)" not_enabled dnsmasq.service
check "hostapd does not start at boot (wifi-connect starts its own copy when needed)" not_enabled hostapd.service

echo "Nothing left behind by the build"
check "no SSH host keys are part of the image" bash -c "! ls '$ROOT'/etc/ssh/ssh_host_*_key 2>/dev/null | grep -q ."
check "no npm cache of root is part of the image" test ! -e "$ROOT/root/.npm"

if [ "$RUN" -eq 1 ]; then
  echo "Programs from the image run"
  NODE_VERSION="$(chroot "$ROOT" /opt/homebridge/bin/node -v 2>/dev/null)"
  check "Node.js runs (${NODE_VERSION:-no answer})" test -n "$NODE_VERSION"
  check "Node.js is the version in the manifest" test "$NODE_VERSION" = "$(manifest_version "NodeJS")"
  check "the wifi-connect copy of Node.js runs wifi-connect" chroot "$ROOT" /opt/wifi-connect/bin/node /opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect/main.js --version
  check "ffmpeg runs" chroot "$ROOT" /usr/local/bin/ffmpeg -version
  check "the Homebridge site config passes nginx's own check" nginx_config_ok
fi

echo
if [ "$FAILED" -gt 0 ]; then
  echo "Image check FAILED: ${FAILED} problem(s). No release must be made from this image."
  exit 1
fi

echo "Image check passed."
