#!/usr/bin/env python3
import json
import zipfile
import hashlib
import os
import argparse
from datetime import date
import glob

# Credits for this go to https://github.com/guysoft/CustomPiOS/blob/devel/src/make_rpi-imager-snipplet.py


def calculate_sha256(data):
    sha256_hash = hashlib.sha256()
    sha256_hash.update(data)
    return sha256_hash.hexdigest()


def calculate_sha256_zip(zip_file_path):
    # Calculate the SHA256 hash of the zip file
    with open(zip_file_path, 'rb') as file:
        sha256_hash = hashlib.sha256()
        while True:
            # Read the file in chunks
            chunk = file.read(4096)
            if not chunk:
                break
            sha256_hash.update(chunk)

        zip_hash = sha256_hash.hexdigest()

    # Open the zip file in binary mode
    with zipfile.ZipFile(zip_file_path, 'r') as zip_obj:
        # Get the list of file names in the zip
        file_names = zip_obj.namelist()

        if file_names:
            # Get the first file name in the zip
            first_file_name = file_names[0]

            # Calculate the SHA256 hash of the first file's data within the zip
            sha256_hash = hashlib.sha256()
            with zip_obj.open(first_file_name) as first_file:
                while True:
                    # Read the first file's data in chunks
                    chunk = first_file.read(4096)
                    if not chunk:
                        break
                    sha256_hash.update(chunk)

            first_file_hash = sha256_hash.hexdigest()

            return zip_hash, first_file_hash

    # Return None if the zip file is empty
    return zip_hash, None


def handle_arg(key, optional=False):
    if optional and key not in os.environ.keys():
        return
    if key in os.environ.keys():
        return os.environ[key]
    else:
        print("Error: Missing value in your distro config file for rpi-imager json generator: " + str(key))
        exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        add_help=True, description='Create a json snipplet from an image to be used with the make_rpi-imager_list.py and eventually published in a repo')
    parser.add_argument('workspace_suffix', nargs='?', default="default",
                        type=str, help='Suffix of workspace folder')
    parser.add_argument('-u', '--rpi_imager_url', type=str,
                        default="MISSING_URL", help='url to the uploaded image url')

    args = parser.parse_args()

    workspace_path = os.path.join(os.getcwd(), "pi-gen", "deploy")
    if args.workspace_suffix != "" and args.workspace_suffix != "default":
        workspace_path += "-" + args.workspace_suffix

    name = handle_arg("RPI_IMAGER_NAME")
    description = handle_arg("RPI_IMAGER_DESCRIPTION")
    url = args.rpi_imager_url
    icon = handle_arg("RPI_IMAGER_ICON")
    website = handle_arg("RPI_IMAGER_WEBSITE", True)
    release_date = date.today().strftime("%Y-%m-%d")

    devices=[]
    devices = json.loads(handle_arg("RPI_IMAGER_DEVICES"))

 #   print("devices: ", devices)
    zip_local = glob.glob(os.path.join(workspace_path, "*.zip"))[0]

    if url == "MISSING_URL":
        url = os.path.basename(zip_local)

    output_path = os.path.join(workspace_path, "rpi-image-repo.json")

    json_out = {"name": name,
                "description": description,
                "init_format": "systemd",
                "url": url,
                "icon": icon,
                "release_date": release_date
                }

    json_out["devices"] = [json.loads(json.dumps(i)) for i in devices]
    if website is not None:
        json_out["website"] = website

    json_out["extract_size"] = None
    with zipfile.ZipFile(zip_local) as zipSize:
        json_out["extract_size"] = zipSize.filelist[0].file_size

    json_out["image_download_size"] = os.stat(zip_local).st_size

    json_out["extract_sha256"] = None
    json_out["image_download_sha256"] = None
    json_out["image_download_sha256"], json_out["extract_sha256"] = calculate_sha256_zip(
        zip_local)

    output_json = {}
    output_json['os_list'] = []
    output_json['os_list'].append(json_out)

    with open(output_path, "w") as w:
        json.dump(output_json, w, indent=2)

    print("Done generating rpi-imager json snipplet to " + output_path)
