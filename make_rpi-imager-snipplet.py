#!/usr/bin/env python3
import json
import zipfile
import hashlib
import os
import argparse
from datetime import date
import glob

# Credits for the go to https://github.com/guysoft/CustomPiOS/blob/devel/src/make_rpi-imager-snipplet.py


def handle_arg(key, optional=False):
    if optional and key not in os.environ.keys():
        return
    if key in os.environ.keys():
        return os.environ[key]
    else:
        print("Error: Missing value in your distro config file for rpi-imager json generator: " + str(key))
        exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=True, description='Create a json snipplet from an image to be used with the make_rpi-imager_list.py and eventually published in a repo')
    parser.add_argument('workspace_suffix', nargs='?', default="default", type=str, help='Suffix of workspace folder')
    parser.add_argument('-u', '--rpi_imager_url', type=str, default="MISSING_URL", help='url to the uploaded image url')
    
    args = parser.parse_args()
    
    workspace_path = os.path.join(os.getcwd(), "deploy")
    if args.workspace_suffix != "" and args.workspace_suffix != "default":
        workspace_path += "-" + args.workspace_suffix
    
    name = handle_arg("RPI_IMAGER_NAME")
    description = handle_arg("RPI_IMAGER_DESCRIPTION")
    url = args.rpi_imager_url
    icon = handle_arg("RPI_IMAGER_ICON")
    website = handle_arg("RPI_IMAGER_WEBSITE", True)
    release_date = date.today().strftime("%Y-%m-%d")
    print("workspace_path " + workspace_path);
    zip_local = glob.glob(os.path.join(workspace_path,"*.zip"))[0]
    
    if url == "MISSING_URL":
        url = os.path.basename(zip_local)
        

    output_path = os.path.join(workspace_path, "rpi-image-repo.json")
    
    json_out = {"name": name,
                "description": description,
                "url": url,
                "icon": icon,
                "release_date": release_date,
                }
    
    if website is not None:
        json_out["website"] = website

    img_sha256_path = glob.glob(os.path.join(workspace_path,"*.sha256"))[0]
    json_out["extract_sha256"] = None
    with open(img_sha256_path, 'r') as f:
        json_out["extract_sha256"] = f.read().split()[0]

    json_out["extract_size"] = None
    with zipfile.ZipFile(zip_local) as zipfile:
        json_out["extract_size"] = zipfile.filelist[0].file_size
    
    json_out["image_download_size"] = os.stat(zip_local).st_size

    json_out["image_download_sha256"] = None
    with open(zip_local,"rb") as f:
        json_out["image_download_sha256"] = hashlib.sha256(f.read()).hexdigest()
    
    with open(output_path, "w") as w:
        json.dump(json_out, w, indent=2)
    
    print("Done generating rpi-imager json snipplet")
