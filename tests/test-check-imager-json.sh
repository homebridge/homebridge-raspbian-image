#!/usr/bin/env bash
# rpi-image-repo.json is read by Raspberry Pi Imager. scripts/check-imager-json.py is the gate in
# front of homebridge.io: it must pass a good file and stop every kind of wrong file.
. "$(dirname "$0")/lib.sh"

CHECK="$REPO/scripts/check-imager-json.py"
URL="https://github.com/homebridge/homebridge-raspbian-image/releases/download"

cat > "$W/good.json" <<JSON
{
  "os_list": [
    {
      "name": "Homebridge trixie (32bit)",
      "description": "Official Homebridge Raspberry Pi Image trixie (32bit)",
      "init_format": "systemd",
      "url": "$URL/v2.0.26/image_2026-11-19-Homebridge-trixie-32bit.zip",
      "icon": "https://example.invalid/icon.png",
      "release_date": "2026-11-19",
      "devices": ["pi5-32bit", "pi4-32bit", "pi3-32bit", "pi2-32bit"],
      "website": "https://github.com/homebridge/homebridge-raspbian-image/wiki/Getting-Started",
      "extract_size": 3430940672,
      "image_download_size": 990622777,
      "extract_sha256": "ed58469dfbee785471c30df531207539d89649093eb6b4014ea1f2839d59e33c",
      "image_download_sha256": "26cbff668b090b59ceb811eb793050e50e4179ea9703d3112412f60571e417e6"
    },
    {
      "name": "Homebridge trixie (64bit)",
      "description": "Official Homebridge Raspberry Pi Image trixie (64bit) - Recommended",
      "init_format": "systemd",
      "url": "$URL/v2.0.26/image_2026-11-19-Homebridge-trixie-64bit.zip",
      "icon": "https://example.invalid/icon.png",
      "release_date": "2026-11-19",
      "devices": ["pi5-64bit", "pi4-64bit", "pi3-64bit"],
      "website": "https://github.com/homebridge/homebridge-raspbian-image/wiki/Getting-Started",
      "extract_size": 3841982464,
      "image_download_size": 1042391150,
      "extract_sha256": "fd54223913592474d68fc27f4c1183a88e1609d829c95099c1cbba8112e71951",
      "image_download_sha256": "5cc28ce71d1ead28e5c0a72cf8de9f8f96b44c18ae1831fb6a19bf7bc5c1e44a"
    }
  ]
}
JSON

cat > "$W/assets.json" <<'JSON'
{"assets": [
  {"name": "image_2026-11-19-Homebridge-trixie-32bit.zip", "size": 990622777},
  {"name": "image_2026-11-19-Homebridge-trixie-64bit.zip", "size": 1042391150},
  {"name": "rpi-image-repo.json", "size": 1900}
]}
JSON

is "a good file passes" "$CHECK" "$W/good.json" --tag v2.0.26
is "a good file passes with the number of images and the release files" "$CHECK" "$W/good.json" --tag v2.0.26 --entries 2 --assets "$W/assets.json"

# wrong <text> <jq filter that breaks the good file> [extra arguments]
wrong() {
  local text="$1" filter="$2"
  shift 2
  jq "$filter" "$W/good.json" > "$W/bad.json"
  isnt "stops when $text" "$CHECK" "$W/bad.json" --tag v2.0.26 "$@"
}

isnt "stops when the links point at another release" "$CHECK" "$W/good.json" --tag v2.0.27
isnt "stops on a tag that is not a release tag" "$CHECK" "$W/good.json" --tag latest
wrong "one image is missing and two are expected" 'del(.os_list[0])' --entries 2
wrong "the list is empty" '.os_list = []'
wrong "the top level has another field" '. + {"extra": 1}'
wrong "a field is missing" 'del(.os_list[1].extract_sha256)'
wrong "a field is added" '.os_list[1].subitems_url = "https://example.invalid"'
wrong "init_format is not systemd" '.os_list[0].init_format = "cloudinit"'
wrong "a link is not a release file" '.os_list[1].url = "https://example.invalid/image.zip"'
wrong "a link has a folder after the tag" '.os_list[1].url = "'"$URL"'/v2.0.26/../v1/x.zip"'
wrong "a link is not a zip file" '.os_list[1].url = "'"$URL"'/v2.0.26/image.img"'
wrong "a device name is not one Imager knows" '.os_list[1].devices = ["pi5-64bit", "pi6"]'
wrong "the device list is empty" '.os_list[1].devices = []'
wrong "a checksum is too short" '.os_list[1].image_download_sha256 = "abc123"'
wrong "a size is text" '.os_list[1].extract_size = "3841982464"'
wrong "the unpacked size is smaller than the download" '.os_list[1].extract_size = 5'
wrong "the date has another form" '.os_list[1].release_date = "19/11/2026"'
wrong "two images have the same name" '.os_list[1].name = .os_list[0].name'
wrong "a size differs from the release file" '.os_list[1].image_download_size = 1042391151' --assets "$W/assets.json"
wrong "a file is not in the release" '.os_list[1].url = "'"$URL"'/v2.0.26/other.zip"' --assets "$W/assets.json"

echo 'not json' > "$W/bad.json"
isnt "stops when the file is not JSON" "$CHECK" "$W/bad.json" --tag v2.0.26
isnt "stops when the file does not exist" "$CHECK" "$W/none.json" --tag v2.0.26

# the file the build makes today must pass its own gate (the shape is an outside contract)
mkdir -p "$W/d/pi-gen/deploy" && cp "$REPO/make_rpi-imager-snipplet.py" "$W/d/"
( cd "$W/d/pi-gen/deploy" && head -c 4096 /dev/zero > test.img && python3 -c "import zipfile; zipfile.ZipFile('image_test.zip', 'w', zipfile.ZIP_DEFLATED).write('test.img')" && rm test.img )
( cd "$W/d" && RPI_IMAGER_NAME="Homebridge trixie (64bit)" RPI_IMAGER_DESCRIPTION=d RPI_IMAGER_ICON=https://example.invalid/i.png \
  RPI_IMAGER_WEBSITE=https://example.invalid/w RPI_IMAGER_DEVICES='["pi5-64bit"]' \
  python3 ./make_rpi-imager-snipplet.py --rpi_imager_url "$URL/v2.0.26/image_test.zip" > /dev/null )
is "the file the build makes passes the gate" "$CHECK" "$W/d/pi-gen/deploy/rpi-image-repo.json" --tag v2.0.26 --entries 1
same "the file the build makes has the fields Imager reads, in the same order as today" \
  "$(jq -c '.os_list[0] | keys_unsorted' "$W/d/pi-gen/deploy/rpi-image-repo.json")" \
  '["name","description","init_format","url","icon","release_date","devices","website","extract_size","image_download_size","extract_sha256","image_download_sha256"]'

finish
