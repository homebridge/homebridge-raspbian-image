#!/usr/bin/env bash
# scripts/check-image.sh must pass on a good image and fail on each kind of broken image.
. "$(dirname "$0")/lib.sh"

CHECK="$REPO/scripts/check-image.sh"
ARGS=(--arch arm64 --tag v9.9.9 --apt-pkg 2.0.26 --wifi-connect 4.2.2)
# files made by a test are only owned by root when the test runs as root
[ "$(id -u)" -eq 0 ] || ARGS+=(--no-owner-check)

# Makes a folder that looks like the root of a good image.
good_image() {
  local r="$1" wants="$1/etc/systemd/system/multi-user.target.wants"
  rm -rf "$r"
  mkdir -p "$r/opt/homebridge/bin" "$r/opt/homebridge/lib/node_modules/homebridge-config-ui-x" \
    "$r/var/lib/homebridge/node_modules/homebridge" "$r/var/lib/dpkg" "$wants" \
    "$r/etc/systemd/system/homebridge.service.d" "$r/etc/sudoers.d" "$r/etc/nginx/sites-available" \
    "$r/etc/nginx/sites-enabled" "$r/etc/hb-service/homebridge/prestart.d" "$r/etc/ssh" \
    "$r/usr/local/sbin" "$r/usr/local/bin" "$r/root" "$r/tmp" \
    "$r/opt/wifi-connect/bin" "$r/opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect"
  for program in opt/homebridge/bin/node opt/wifi-connect/bin/node usr/local/bin/ffmpeg usr/local/sbin/hb-config \
    usr/local/sbin/first-boot-homebridge usr/local/sbin/nginx-homebridge-self-signed-cert \
    etc/hb-service/homebridge/prestart.d/20-hb-nginx-check; do
    printf '#!/bin/sh\n' > "$r/$program"
    chmod 755 "$r/$program"
  done
  echo '{}' > "$r/opt/homebridge/lib/node_modules/homebridge-config-ui-x/package.json"
  echo '{}' > "$r/var/lib/homebridge/node_modules/homebridge/package.json"
  touch "$r/opt/homebridge/hb-service-shim"
  echo '{"version":"4.2.2"}' > "$r/opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect/package.json"
  touch "$r/opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect/main.js"
  for unit in homebridge nginx wifi-connect first-boot-homebridge nginx-homebridge-self-signed-cert NetworkManager; do
    ln -s "/usr/lib/systemd/system/$unit.service" "$wants/$unit.service"
  done
  cp "$REPO/stage3_homebridge/02-wifi-connect/files/wifi-connect.service" "$r/etc/systemd/system/"
  cp "$REPO/stage3_homebridge/03-nginx/files/homebridge.local" "$r/etc/nginx/sites-available/"
  ln -s /etc/nginx/sites-available/homebridge.local "$r/etc/nginx/sites-enabled/homebridge.local"
  printf '[Service]\nEnvironment="UIX_CAN_SHUTDOWN_RESTART_HOST=1"\nEnvironment="UIX_STORAGE_PATH=/var/lib/homebridge"\n' > "$r/etc/systemd/system/homebridge.service.d/override.conf"
  printf 'root:x:0:0:root:/root:/bin/bash\nhomebridge:x:999:999::/home/homebridge:/bin/bash\n' > "$r/etc/passwd"
  printf 'sudo:x:27:pi\nhomebridge:x:999:\n' > "$r/etc/group"
  cp "$FILES/010_homebridge-nopasswd" "$r/etc/sudoers.d/" && chmod 440 "$r/etc/sudoers.d/010_homebridge-nopasswd"
  printf 'Package: adduser\nVersion: 3.1\n\nPackage: homebridge\nStatus: install ok installed\nVersion: 2.0.26\n\n' > "$r/var/lib/dpkg/status"
  echo 'v9.9.9 (64bit)' > "$r/etc/hb-release"
  echo '8581' > "$r/etc/hb-ui-port"
  echo 'Homebridge' > "$r/etc/issue" && chmod 644 "$r/etc/issue"
  cat > "$r/opt/homebridge/homebridge_raspbian_image_arm64.manifest" <<'MANIFEST'
Homebridge Raspbian arm64 Image Package Manifest

Release Version: v9.9.9 (64bit)

| Package | Version |
|:-------:|:-------:|
| Debian | trixie |
| NodeJS | v24.1.0 |
| Homebridge UI | 5.30.1 |
| Homebridge | 2.5.0 |
| ffmpeg for homebridge | v2.2.2 |
| Homebridge APT Package | 2.0.26 |
| WiFi Connect | 4.2.2 |
MANIFEST
}

R="$W/root"

good_image "$R"
out="$("$CHECK" "$R" "${ARGS[@]}" 2>&1)"
same "a good image passes" "$?" "0"
is "a good image has no failed line" bash -c "! grep -q FAIL <<< \"\$1\"" -- "$out"

# breaks <text> <shell lines that break the image in $R>
breaks() {
  local text="$1"
  good_image "$R"
  ( cd "$R" && eval "$2" )
  if "$CHECK" "$R" "${ARGS[@]}" > "$W/out" 2>&1; then
    fail "fails when $text" "the check passed"
  elif grep -q "^  FAIL" "$W/out"; then
    ok "fails when $text"
  else
    fail "fails when $text" "non-zero exit but no FAIL line"
  fi
}

breaks "Node.js is missing" 'rm opt/homebridge/bin/node'
breaks "Homebridge is missing" 'rm -r var/lib/homebridge/node_modules/homebridge'
breaks "the UI is missing" 'rm -r opt/homebridge/lib/node_modules/homebridge-config-ui-x'
breaks "the homebridge service does not start at boot" 'rm etc/systemd/system/multi-user.target.wants/homebridge.service'
breaks "nginx does not start at boot" 'rm etc/systemd/system/multi-user.target.wants/nginx.service'
breaks "wifi-connect does not start at boot" 'rm etc/systemd/system/multi-user.target.wants/wifi-connect.service'
breaks "the first boot service does not start at boot" 'rm etc/systemd/system/multi-user.target.wants/first-boot-homebridge.service'
breaks "the service settings file is the one from the apt package" 'printf "[Service]\nUser=1000\n" > etc/systemd/system/homebridge.service.d/override.conf'
breaks "the homebridge user is in the sudo group" 'printf "sudo:x:27:pi,homebridge\n" > etc/group'
breaks "the sudo rule file can be read by everyone" 'chmod 644 etc/sudoers.d/010_homebridge-nopasswd'
breaks "/etc/hb-release does not hold the release tag" 'echo Homebridge-trixie-64bit > etc/hb-release'
breaks "the apt package is another version" 'sed -i "s/^Version: 2.0.26/Version: 2.0.25/" var/lib/dpkg/status'
breaks "wifi-connect is another version" 'echo "{\"version\":\"4.2.1\"}" > opt/wifi-connect/lib/node_modules/@homebridge/wifi-connect/package.json'
breaks "wifi-connect has no Node.js of its own" 'rm opt/wifi-connect/bin/node'
breaks "the wifi-connect service uses /opt/homebridge" 'sed -i "s#^ExecStart=.*#ExecStart=/opt/homebridge/bin/node main.js#" etc/systemd/system/wifi-connect.service'
breaks "the wifi-connect service holds up Homebridge" 'sed -i "s#^Before=.*#Before=nginx.service homebridge.service#" etc/systemd/system/wifi-connect.service'
breaks "the manifest has no Node.js row" 'sed -i "/NodeJS/d" opt/homebridge/homebridge_raspbian_image_arm64.manifest'
breaks "the manifest is missing" 'rm opt/homebridge/homebridge_raspbian_image_arm64.manifest'
breaks "ffmpeg is missing" 'rm usr/local/bin/ffmpeg'
breaks "/etc/issue is marked as a program" 'chmod 755 etc/issue'
breaks "dnsmasq starts at boot" 'ln -s /usr/lib/systemd/system/dnsmasq.service etc/systemd/system/multi-user.target.wants/dnsmasq.service'
breaks "an SSH host key is in the image" 'touch etc/ssh/ssh_host_ed25519_key'
breaks "a certificate is in the image" 'mkdir -p etc/nginx/ssl && touch etc/nginx/ssl/homebridge.local.key'
breaks "root has an npm cache" 'mkdir root/.npm'
if [ "$(id -u)" -eq 0 ]; then
  breaks "a file in /opt/wifi-connect belongs to another user" 'chown 1000 opt/wifi-connect/bin/node'
  breaks "a file in /opt/wifi-connect can be changed by everyone" 'chmod 777 opt/wifi-connect/bin/node'
fi

isnt "stops when no folder is given" "$CHECK" --arch arm64 --tag v1.0.0
isnt "stops on an unknown architecture" "$CHECK" "$R" --arch x86 --tag v1.0.0

finish
