#!/bin/bash

# Homebridge Image does not need Stage 2 export files
rm -f ../stage[2]/EXPORT*
# Homebridge Image does not need Cloud-Init
rm -rf ../stage[2]/04-cloud-init