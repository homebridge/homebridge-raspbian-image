#!/usr/bin/env bash
# 20-hb-nginx-check runs as root before every Homebridge start and reads a file that the
# Homebridge service user owns. Whatever is in that file, the nginx config must stay valid and
# only the one port line may change.
. "$(dirname "$0")/lib.sh"

SITE="$REPO/stage3_homebridge/03-nginx/files/homebridge.local"

fake systemctl 'exit 0'       # nginx is "active"
fake nginx 'exit 0'

# run_with <content of config.json | "-" for no file>: runs the script on a fresh copy of the site config
run_with() {
  rm -rf "$W/c" "$W/calls.log"
  mkdir -p "$W/c"
  sed -e "s#/var/lib/homebridge/config.json#$W/c/config.json#g" \
      -e "s#/etc/hb-ui-port#$W/c/hb-ui-port#g" \
      -e "s#/etc/nginx/sites-available/homebridge.local#$W/c/homebridge.local#g" \
      "$FILES/20-hb-nginx-check" > "$W/c/check"
  cp "${SITE_IN:-$SITE}" "$W/c/homebridge.local"
  [ "$1" = "-" ] || printf '%s\n' "$1" > "$W/c/config.json"
  PATH="$W/bin:$PATH" bash "$W/c/check" > "$W/c/out" 2>&1
  code=$?
}

port_line() { grep 'proxy_pass' "$W/c/homebridge.local" | head -n 1 | tr -s ' ' | sed 's/^ //'; }
changed_lines() { diff "${SITE_IN:-$SITE}" "$W/c/homebridge.local" | grep -c '^>'; }

run_with '{"platforms":[{"platform":"config","name":"Config","port":8080}]}'
same "uses the port from config.json" "$(cat "$W/c/hb-ui-port")" "8080"
same "writes that port into the nginx config" "$(port_line)" "proxy_pass http://127.0.0.1:8080;"
same "changes one line only" "$(changed_lines)" "1"
same "exits with code 0" "$code" "0"
has "reloads nginx after a change" "$W/calls.log" "nginx -s reload"

run_with '{"platforms":[{"platform":"config","name":"Config","port":8581}]}'
same "leaves the nginx config as it is when the port did not change" "$(changed_lines)" "0"
same "does not reload nginx when nothing changed" "$(calls | grep -c 'nginx -s reload')" "0"

# every one of these must give the default port, and must not put its text into the nginx config
bad_port() {
  run_with "$2"
  same "$1: falls back to port 8581" "$(cat "$W/c/hb-ui-port")" "8581"
  same "$1: the nginx config keeps a plain port line" "$(port_line)" "proxy_pass http://127.0.0.1:8581;"
  same "$1: nothing else in the nginx config changed" "$(changed_lines)" "0"
}

bad_port "no port" '{"platforms":[{"platform":"config","name":"Config"}]}'
bad_port "port null" '{"platforms":[{"platform":"config","port":null}]}'
bad_port "port is text with nginx settings in it" '{"platforms":[{"platform":"config","port":"$host; access_log /tmp/any-file; #"}]}'
bad_port "port is text with a new line" '{"platforms":[{"platform":"config","port":"8581;\n}\nserver { listen 81; "}]}'
bad_port "port 0" '{"platforms":[{"platform":"config","port":0}]}'
bad_port "port too high" '{"platforms":[{"platform":"config","port":65536}]}'
bad_port "port with six digits" '{"platforms":[{"platform":"config","port":100000}]}'
bad_port "negative port" '{"platforms":[{"platform":"config","port":-8581}]}'
bad_port "port with a fraction" '{"platforms":[{"platform":"config","port":8581.5}]}'
bad_port "port is a list" '{"platforms":[{"platform":"config","port":[8080]}]}'
bad_port "port is an object" '{"platforms":[{"platform":"config","port":{"a":8080}}]}'
bad_port "port with a leading zero" '{"platforms":[{"platform":"config","port":"08080"}]}'
bad_port "no UI block" '{"platforms":[{"platform":"other","port":9000}]}'
bad_port "platforms is not a list" '{"platforms":"config"}'
bad_port "config.json is not JSON" 'this is not json'
bad_port "config.json is empty" ''
bad_port "config.json is missing" '-'

run_with '{"platforms":[{"platform":"config","port":"8080"}]}'
same "accepts a port written as text with digits only" "$(cat "$W/c/hb-ui-port")" "8080"

run_with '{"platforms":[{"platform":"other"},{"platform":"config","port":9000},{"platform":"config","port":9001}]}'
same "uses the first UI block when there are two" "$(cat "$W/c/hb-ui-port")" "9000"

run_with '{"platforms":[{"platform":"config","port":65535}]}'
same "accepts the highest port" "$(cat "$W/c/hb-ui-port")" "65535"

# a user added their own proxy for another service, after and before the Homebridge block
{
  printf '# my own service\nserver {\n  listen 8080;\n  location / {\n    proxy_pass http://127.0.0.1:1880;\n  }\n  location /api {\n    proxy_pass http://127.0.0.1:1881;\n  }\n}\n'
} > "$W/own"
cat "$SITE" "$W/own" > "$W/site-after"
SITE_IN="$W/site-after" run_with '{"platforms":[{"platform":"config","port":8080}]}'
same "a user's own proxy_pass lines after the Homebridge block stay as they are" "$(grep -c '127.0.0.1:188[01];' "$W/c/homebridge.local")" "2"
same "the Homebridge line is still updated" "$(grep -c '127.0.0.1:8080;' "$W/c/homebridge.local")" "1"

{
  printf 'server {\n  listen 8080;\n  location /nodered {\n    proxy_pass http://127.0.0.1:1880;\n  }\n}\n'
} > "$W/own"
cat "$W/own" "$SITE" > "$W/site-before"
SITE_IN="$W/site-before" run_with '{"platforms":[{"platform":"config","port":8080}]}'
same "a user's own proxy_pass line before the Homebridge block stays as it is" "$(grep -c '127.0.0.1:1880;' "$W/c/homebridge.local")" "1"
same "the Homebridge line is still updated there too" "$(grep -c '127.0.0.1:8080;' "$W/c/homebridge.local")" "1"

# the config made by "hb-config -> Nginx Options" has the same block
printf 'server {\n  listen 80;\n  location / {\n    proxy_pass                  http://127.0.0.1:8581;\n    proxy_http_version          1.1;\n  }\n}\n' > "$W/site-small"
SITE_IN="$W/site-small" run_with '{"platforms":[{"platform":"config","port":8080}]}'
same "works on a small config with one block" "$(grep -c '127.0.0.1:8080;' "$W/c/homebridge.local")" "1"

# nginx itself must accept the result (runs when nginx is installed, as it is in CI)
run_with '{"platforms":[{"platform":"config","port":"$host; access_log /tmp/any-file; #"}]}'
answer="$(nginx_accepts "$W/c/homebridge.local")"
case $? in
  0) ok "nginx accepts the config after a run with a hostile port value" ;;
  2) echo "  skip  nginx is not installed here" ;;
  *) fail "nginx accepts the config after a run with a hostile port value" "$answer" ;;
esac

finish
