#!/usr/bin/env bash
# The nginx config of the image, the one hb-config writes, and the self-signed certificate.
. "$(dirname "$0")/lib.sh"

SITE="$REPO/stage3_homebridge/03-nginx/files/homebridge.local"
TOOL="$FILES/hb-config-new"

# check_with_nginx <text> <file>: nginx itself must accept the file, with no warning
check_with_nginx() {
  local answer
  answer="$(nginx_accepts "$2")"
  case $? in
    0) ok "$1" ;;
    2) echo "  skip  $1 (nginx is not installed here)" ;;
    *) fail "$1" "$answer" ;;
  esac
}

check_with_nginx "nginx accepts the config of the image, with no warning" "$SITE"
has "the image config turns HTTP/2 on the current way" "$SITE" "http2 on;"
isnt "the image config does not use the old 'listen ... http2' form" grep -qE 'listen .*http2' "$SITE"
has "the image config sends the X-Forwarded-For header" "$SITE" 'X-Forwarded-For $proxy_add_x_forwarded_for;'
isnt "no file has the misspelled header name" grep -rq 'X-Forward-For' "$SITE" "$TOOL"

# hb-config -> Nginx Options. whiptail: "yes" to the question, and the given boxes ticked.
# make_config <nginx version> <ticked boxes, one per line>
make_config() {
  rm -rf "$W/root" "$W/calls.log" "$W/bin"
  mkdir -p "$W/bin" "$W/root/etc/nginx/sites-available" "$W/root/usr/local/sbin" "$W/root/tmp"
  echo "${UI_PORT_FILE-8581}" > "$W/root/etc/hb-ui-port"
  printf '#!/bin/sh\nexit 0\n' > "$W/root/usr/local/sbin/nginx-homebridge-self-signed-cert"
  chmod +x "$W/root/usr/local/sbin/nginx-homebridge-self-signed-cert"
  printf '%s\n' "$2" > "$W/ticked"
  fake whiptail "case \"\$*\" in *--checklist*) cat \"$W/ticked\" >&2 ;; esac; exit 0"
  fake nginx "echo 'nginx version: nginx/$1' >&2"
  fake systemctl 'exit 0'
  hb_config do_configure_nginx
  MADE="$W/root/etc/nginx/sites-available/homebridge.local"
}

make_config 1.26.3 $'1\n2'
has "new nginx: the config turns HTTP/2 on with 'http2 on;'" "$MADE" "http2 on;"
has "new nginx: port 443 listens with ssl" "$MADE" "listen 443 ssl;"
has "port 80 is on when its box is ticked" "$MADE" "listen 80;"
has "the config proxies to the UI port" "$MADE" "proxy_pass                  http://127.0.0.1:8581;"
has "the config sends the X-Forwarded-For header" "$MADE" 'X-Forwarded-For $proxy_add_x_forwarded_for;'
has "nginx variables are written as they are" "$MADE" 'proxy_set_header            Host $host;'
check_with_nginx "nginx accepts the config hb-config writes, with no warning" "$MADE"
has "nginx is started again" "$W/calls.log" "systemctl restart nginx"

make_config 1.22.1 $'1\n2'
has "old nginx (Debian 12): the config uses 'listen 443 ssl http2;'" "$MADE" "listen 443 ssl http2;"
isnt "old nginx (Debian 12): no 'http2 on;' line, which it does not know" grep -q 'http2 on;' "$MADE"

make_config 1.25.1 $'1\n2'
has "nginx 1.25.1 is the first with 'http2 on;'" "$MADE" "http2 on;"
make_config 1.25.0 $'1\n2'
isnt "nginx 1.25.0 still gets the old form" grep -q 'http2 on;' "$MADE"
make_config 1.9.15 $'1\n2'
isnt "version numbers are compared as numbers (1.9 is older than 1.25)" grep -q 'http2 on;' "$MADE"

make_config 1.26.3 $'1\n2\n3'
has "with the redirect ticked, port 80 only redirects to https" "$MADE" 'return 302 https://$host$request_uri;'
check_with_nginx "nginx accepts the config with the redirect" "$MADE"

make_config 1.26.3 '2'
isnt "port 80 is off when its box is not ticked" grep -q 'listen 80;' "$MADE"
check_with_nginx "nginx accepts the config with https only" "$MADE"

UI_PORT_FILE='8581; evil' make_config 1.26.3 $'1\n2'
has "a port file with other text gives the default port" "$MADE" "proxy_pass                  http://127.0.0.1:8581;"
UI_PORT_FILE='9000' make_config 1.26.3 $'1\n2'
has "the port from the port file is used" "$MADE" "proxy_pass                  http://127.0.0.1:9000;"

# the script 20-hb-nginx-check must still find its line in the config hb-config writes
sed -e "s#/var/lib/homebridge/config.json#$W/config.json#g" -e "s#/etc/hb-ui-port#$W/root/etc/hb-ui-port#g" \
    -e "s#/etc/nginx/sites-available/homebridge.local#$MADE#g" "$FILES/20-hb-nginx-check" > "$W/check"
echo '{"platforms":[{"platform":"config","port":8090}]}' > "$W/config.json"
PATH="$W/bin:$PATH" bash "$W/check" > /dev/null 2>&1
has "the port script can update the config hb-config writes" "$MADE" "proxy_pass                  http://127.0.0.1:8090;"

# ---- the self-signed certificate (uses the real openssl)
CERT_SCRIPT="$REPO/stage3_homebridge/03-nginx/files/nginx-homebridge-self-signed-cert"
C="$W/cert"
SSL="$C/etc/nginx/ssl"
cert_script() {
  sed -E "s#(^|[[:space:]=\"])/etc/nginx/#\1$C/etc/nginx/#g" "$CERT_SCRIPT" > "$W/cert-script"
  ( PATH="$W/bin:$PATH" bash "$W/cert-script" ) > "$W/cert.log" 2>&1
}
fresh_cert() { rm -rf "$C" && mkdir -p "$C/etc/nginx/sites-available" && touch "$C/etc/nginx/sites-available/homebridge.local"; }
names() { openssl x509 -noout -ext subjectAltName -in "$SSL/homebridge.local.crt" 2> /dev/null | tail -n 1 | tr -d ' '; }
sum() { sha256sum "$SSL/homebridge.local.crt" | cut -d' ' -f1; }
# old_cert <subject> <days>: a self-signed certificate as made before, valid for <days> days
old_cert() {
  mkdir -p "$SSL"
  openssl req -x509 -newkey rsa:2048 -nodes -sha256 -days "$2" -subj "$1" \
    -keyout "$SSL/homebridge.local.key" -out "$SSL/homebridge.local.crt" 2> /dev/null
}

rm -rf "$W/bin" && mkdir -p "$W/bin"
fake hostname 'echo my-pi'

fresh_cert
cert_script
same "makes a certificate when there is none" "$?" "0"
same "the certificate names localhost, homebridge.local and the Pi's own name" "$(names)" "DNS:localhost,DNS:homebridge.local,IPAddress:127.0.0.1,DNS:my-pi,DNS:my-pi.local"
same "only root can read the key" "$(stat -c '%a' "$SSL/homebridge.local.key")" "600"
is "the certificate is valid for more than two years" openssl x509 -checkend $((800 * 86400)) -noout -in "$SSL/homebridge.local.crt"
isnt "and for less than 826 days (the longest Apple devices accept)" openssl x509 -checkend $((826 * 86400)) -noout -in "$SSL/homebridge.local.crt"
is "the key belongs to the certificate" bash -c "[ \"\$(openssl x509 -noout -pubkey -in '$SSL/homebridge.local.crt' | sha256sum)\" = \"\$(openssl pkey -pubout -in '$SSL/homebridge.local.key' | sha256sum)\" ]"

before="$(sum)"
cert_script
same "a certificate that is still valid is left alone" "$(sum)" "$before"

fresh_cert && old_cert "/CN=localhost" 10 && before="$(sum)"
cert_script
isnt "an old certificate made by the image that expires soon is replaced" test "$(sum)" = "$before"
is "the new one is valid for a long time again" openssl x509 -checkend $((800 * 86400)) -noout -in "$SSL/homebridge.local.crt"

fresh_cert && old_cert "/O=Homebridge Raspberry Pi Image/CN=homebridge.local" 10 && before="$(sum)"
cert_script
isnt "a newer certificate made by the image that expires soon is replaced" test "$(sum)" = "$before"

fresh_cert && old_cert "/CN=my-own-name.example.com" 10 && before="$(sum)"
cert_script
same "a certificate the user put there is never replaced, even when it expires soon" "$(sum)" "$before"

fresh_cert && mkdir -p "$SSL" && echo "not a certificate" > "$SSL/homebridge.local.crt" && echo "key" > "$SSL/homebridge.local.key" && before="$(sum)"
cert_script
same "a file that is not a certificate is not replaced" "$(sum)" "$before"

fresh_cert
fake hostname 'echo "bad name; x"'
cert_script
same "a host name with other characters is left out" "$(names)" "DNS:localhost,DNS:homebridge.local,IPAddress:127.0.0.1"

rm -rf "$C" && mkdir -p "$C/etc/nginx/sites-available"
cert_script
isnt "nothing is made when the Homebridge site config is not there" test -e "$SSL"

finish
