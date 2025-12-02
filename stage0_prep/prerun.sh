#!/bin/bash

# Homebridge Image does not need Stage 2 export files
rm -f ../stage[2]/EXPORT*

ls -lR ../..

echo "Copying raspberrypi.gpg to pi-gen stage0/files"
echo "Workaround for https://github.com/RPi-Distro/pi-gen/issues/862"
# Copy raspberrypi.gpg to pi-gen stage0/files
cp files/raspberrypi.gpg ../pi-gen/stage0/files/raspberrypi.gpg
