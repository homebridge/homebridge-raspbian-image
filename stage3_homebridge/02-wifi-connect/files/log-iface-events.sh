#!/usr/bin/env bash

#
# Homebridge Raspbian Image - WiFi Connect
# This script stops the WiFi Connect Hotspot service when eth0 comes up
#

interface=$1
event=$2

if [[ $interface = "eth0" ]] && [[ $event = "up" ]]; then
   systemctl stop wifi-connect.service
   exit 0
fi
