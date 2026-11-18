#!/usr/bin/env python3
"""Joins the Raspberry Pi Imager entries of the images into one rpi-image-repo.json.

Usage: combine-rpi-imager-snipplet.py [file ...]

With no arguments it uses rpi-image-repo-32bit.json and rpi-image-repo-64bit.json in the current
folder, in that order (the 32-bit entry comes first in the list, as it always has). A file that
does not exist is left out, so a release with one image can still be made. It stops when no file
exists at all.
"""
import json
import os
import sys

DEFAULT_FILES = ['rpi-image-repo-32bit.json', 'rpi-image-repo-64bit.json']
OUTPUT_FILE = 'rpi-image-repo.json'


def read_json(file_path):
    with open(file_path, 'r') as file:
        return json.load(file)


def write_json(file_path, data):
    with open(file_path, 'w') as file:
        json.dump(data, file, indent=2)


def main(files):
    combined_list = []

    for file_path in files:
        if not os.path.isfile(file_path):
            print(f"combine-rpi-imager-snipplet: {file_path} not found, left out")
            continue

        combined_list += read_json(file_path)['os_list']
        print(f"combine-rpi-imager-snipplet: added {file_path}")

    if not combined_list:
        print("combine-rpi-imager-snipplet: no image entries found, nothing written", file=sys.stderr)
        return 1

    # Save the combined JSON data to a file
    write_json(OUTPUT_FILE, {"os_list": combined_list})
    print(f"combine-rpi-imager-snipplet: wrote {OUTPUT_FILE} with {len(combined_list)} image(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:] or DEFAULT_FILES))
