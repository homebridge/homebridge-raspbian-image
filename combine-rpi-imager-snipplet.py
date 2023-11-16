#!/usr/bin/env python3
import json

def read_json(file_path):
    with open(file_path, 'r') as file:
        return json.load(file)

def write_json(file_path, data):
    with open(file_path, 'w') as file:
        json.dump(data, file, indent=2)

# Read JSON data from the files
data1 = read_json('rpi-image-repo-32bit.json')
data2 = read_json('rpi-image-repo-64bit.json')

# Combine the lists in the "os_list" key
combined_list = data1['os_list'] + data2['os_list']

# Create a new dictionary with the combined list
combined_data = {"os_list": combined_list}

# Save the combined JSON data to a file
write_json('rpi-image-repo.json', combined_data)
