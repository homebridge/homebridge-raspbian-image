#!/usr/bin/env python3
"""Checks rpi-image-repo.json before it is sent to homebridge.io.

Raspberry Pi Imager reads that file, so a wrong file breaks the Homebridge entry for every
Imager user. This script stops (exit code 1) unless:

  - the file has the shape Imager expects (the same fields as today, no more and no fewer),
  - every download link points at the release with the given tag,
  - (with --assets) every download link is a file of that release, with the same size,
  - (with --entries) the file has that many images in it.

Usage:
  check-imager-json.py rpi-image-repo.json --tag v1.2.3 [--entries 2] [--assets assets.json]

assets.json is the output of: gh release view <tag> --json assets
"""
import argparse
import json
import re
import sys

REPO_URL = "https://github.com/homebridge/homebridge-raspbian-image"

# The fields of one image entry. This list is an outside contract: do not change it by accident.
FIELDS = {
    "name": str,
    "description": str,
    "init_format": str,
    "url": str,
    "icon": str,
    "release_date": str,
    "devices": list,
    "website": str,
    "extract_size": int,
    "image_download_size": int,
    "extract_sha256": str,
    "image_download_sha256": str,
}

# Imager's own names for the Pi models an image can be written to.
DEVICES = {"pi5-64bit", "pi4-64bit", "pi3-64bit", "pi5-32bit", "pi4-32bit", "pi3-32bit", "pi2-32bit"}

SHA256 = re.compile(r"^[0-9a-f]{64}$")
DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
TAG = re.compile(r"^v\d+\.\d+\.\d+$")


def check(data, tag, entries=None, assets=None):
    """Returns a list of problems. An empty list means the file is good."""
    problems = []

    if not isinstance(data, dict) or list(data.keys()) != ["os_list"] or not isinstance(data["os_list"], list):
        return ["the top level must be an object with one field, os_list, which is a list"]

    os_list = data["os_list"]

    if not os_list:
        problems.append("os_list is empty")

    if entries is not None and len(os_list) != entries:
        problems.append(f"os_list has {len(os_list)} image(s), expected {entries}")

    prefix = f"{REPO_URL}/releases/download/{tag}/"
    sizes = {asset.get("name"): asset.get("size") for asset in assets} if assets is not None else None
    names = set()

    for index, entry in enumerate(os_list):
        where = f"image {index + 1}"

        if not isinstance(entry, dict):
            problems.append(f"{where}: must be an object")
            continue

        missing = sorted(set(FIELDS) - set(entry))
        extra = sorted(set(entry) - set(FIELDS))

        if missing:
            problems.append(f"{where}: missing field(s): {', '.join(missing)}")
        if extra:
            problems.append(f"{where}: unknown field(s): {', '.join(extra)}")

        for field, kind in FIELDS.items():
            if field in entry and (not isinstance(entry[field], kind) or isinstance(entry[field], bool)):
                problems.append(f"{where}: {field} must be of type {kind.__name__}")

        if missing or any(not isinstance(entry[f], k) for f, k in FIELDS.items()):
            continue

        where = f"image {index + 1} ({entry['name']})"

        if not entry["name"].strip() or not entry["description"].strip():
            problems.append(f"{where}: name and description must not be empty")
        if entry["name"] in names:
            problems.append(f"{where}: the name is used twice")
        names.add(entry["name"])

        # "systemd" goes together with cloud-init being off in the build. Change both or neither.
        if entry["init_format"] != "systemd":
            problems.append(f"{where}: init_format must be systemd")

        if not entry["url"].startswith(prefix) or not entry["url"].endswith(".zip") or "/" in entry["url"][len(prefix):]:
            problems.append(f"{where}: url must be a .zip file of release {tag}: {entry['url']}")

        if not entry["icon"].startswith("https://") or not entry["website"].startswith("https://"):
            problems.append(f"{where}: icon and website must be https links")

        if not DATE.match(entry["release_date"]):
            problems.append(f"{where}: release_date must look like 2026-01-31")

        if not entry["devices"] or any(device not in DEVICES for device in entry["devices"]):
            problems.append(f"{where}: devices must be a list of Imager device names: {entry['devices']}")

        for field in ("extract_sha256", "image_download_sha256"):
            if not SHA256.match(entry[field]):
                problems.append(f"{where}: {field} must be 64 hex characters")

        if entry["image_download_size"] <= 0 or entry["extract_size"] <= entry["image_download_size"]:
            problems.append(f"{where}: the sizes are not possible (download {entry['image_download_size']}, unpacked {entry['extract_size']})")

        if sizes is not None and entry["url"].startswith(prefix):
            file_name = entry["url"][len(prefix):]

            if file_name not in sizes:
                problems.append(f"{where}: the release has no file called {file_name}")
            elif sizes[file_name] != entry["image_download_size"]:
                problems.append(f"{where}: {file_name} is {sizes[file_name]} bytes in the release, the list says {entry['image_download_size']}")

    return problems


def main():
    parser = argparse.ArgumentParser(description="Check rpi-image-repo.json before it is published")
    parser.add_argument("file")
    parser.add_argument("--tag", required=True, help="the release tag the links must point at, for example v1.2.3")
    parser.add_argument("--entries", type=int, help="how many images the file must hold")
    parser.add_argument("--assets", help="output of: gh release view <tag> --json assets")
    args = parser.parse_args()

    if not TAG.match(args.tag):
        print(f"check-imager-json: not a release tag: {args.tag}", file=sys.stderr)
        return 1

    try:
        with open(args.file, encoding="utf-8") as handle:
            data = json.load(handle)

        assets = None

        if args.assets:
            with open(args.assets, encoding="utf-8") as handle:
                assets = json.load(handle)["assets"]
    except (OSError, ValueError, KeyError, TypeError) as error:
        print(f"check-imager-json: can not read the input: {error}", file=sys.stderr)
        return 1

    problems = check(data, args.tag, args.entries, assets)

    for problem in problems:
        print(f"check-imager-json: {problem}", file=sys.stderr)

    if problems:
        print(f"check-imager-json: {len(problems)} problem(s). The Imager list must not be updated.", file=sys.stderr)
        return 1

    print(f"check-imager-json: {args.file} is good for release {args.tag} ({len(data['os_list'])} image(s))")
    return 0


if __name__ == "__main__":
    sys.exit(main())
