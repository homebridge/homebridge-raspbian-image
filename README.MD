<p align="center">
<img src="https://user-images.githubusercontent.com/3979615/62948461-bae3bd00-be27-11e9-81b5-05c65c388a1e.png" height="120">
</p>

<span align="center">

# Homebridge Raspberry Pi Image

[![Build](https://github.com/oznu/pi-gen/workflows/CI/badge.svg)](https://github.com/oznu/pi-gen/actions)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/oznu/pi-gen?label=Version)](https://github.com/oznu/pi-gen/releases/latest)

</span>

The project provides a free [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) based Raspberry Pi image with [Homebridge](https://github.com/nfarina/homebridge) and [Homebridge Config UI X](https://github.com/oznu/homebridge-config-ui-x) pre-installed.

* Built on Raspbian Lite (no desktop)
* Works on all Raspberry Pi models
* Simple WiFi Setup
* SSL pre-configured (self-signed certificate generated on your device)
* System config command called `homebridge-config` which helps you keep Node.js up-to-date and install additional optional software such as *Pi Hole*, *Node-RED* and the *UniFI Controller*.

## Download

Dowloading the *Homebridge Raspberry Pi Image* is completely free.


<span align="center">
  
### [Download Latest Version](https://github.com/oznu/pi-gen/releases/latest)
  
</span>

## Flashing to SD Card

The easiest way to flash the *Homebridge Raspberry Pi Image* to your SD card is to use [Etcher](https://www.balena.io/etcher/).
  
<p align="center">
    <img src="https://user-images.githubusercontent.com/3979615/74602030-a5ae5a80-50f8-11ea-885c-2e019105d318.gif" height="120">
</p>

1. Download and install the latest version of [Etcher](https://www.balena.io/etcher/).
2. Open Etcher and select the `Homebridge-Raspbian-v0.0.0.zip` file you have [downloaded](https://github.com/oznu/pi-gen/releases/latest). There is no need to extract the `.zip` file first.
3. Choose the drive your SD card has been inserted into.
4. Click Flash.

## First Boot / Network Setup

Now that you have flashed your SD card, you can insert it into your Raspberry Pi.

Before powering on your Raspberry Pi decide if you want to use Ethernet or WiFi to connect to your network.

### Ethernet

**:warning: An Ethernet connection is recommended as this provides the most simple and stable Homebridge setup.**

If you have decided to connect your Raspberry Pi using ethernet, do so before you power on your device for the first time. 

### WiFi Setup

If you need to connect your Raspberry Pi to WiFi, power on your device without an Ethernet cable attached.

After a minute or so, use your phone to scan to new WiFi networks, you should to see a new WiFi hotspot named **Homebridge WiFi Setup**. Connecting to this hotspot will prompt you for the SSID and password for your local WiFi network.

If you enter your WiFi credentials incorrectly the **Homebridge WiFi Setup** hotspot will reappear allowing you to try again.

## Managing Homebridge

The *Homebridge Raspberry Pi Image* allows you to manage your Homebridge install using [Homebridge Config UI X](https://github.com/oznu/homebridge-config-ui-x).

If you're using macOS, Linux or a mobile device, you should be able to access the UI via http://homebridge.local.

If you're using Windows, or `http://homebridge.local` does not work, login to your routers "connected devices" page to find the IP address that was assigned to the Raspberry Pi.

As a last resort, if you plug a monitor into your Raspberry Pi, the IP address will be displayed on the screen once it has finished booting.

<p align="center">
  <img width="600px" src="https://user-images.githubusercontent.com/3979615/71886653-b16d3f80-3190-11ea-9ff8-49dc4ae4fff0.png">
</p>

You should take a moment to review the [Configuration Reference](#configuration-reference) at the bottom of this guide.

## Updating Node.js

To update Node.js run `sudo homebridge-config` and select **Upgrade Node.js**.

This will ensure your Raspberry Pi  is running the latest LTS version of Node.js.

<p align="center">
  <img width="600px" alt="homebridge-config" src="https://user-images.githubusercontent.com/3979615/74602581-4b17fd00-50fe-11ea-8684-c03eaa42d27d.png">
</p>

## SSH Access

SSH is enabled by default. The default username is `pi` with password `raspberry`.

## Configuration Reference

This table contains important information about your setup. You can use the information provided here as a reference when configuring or troubleshooting your environment after setting up Homebridge using the instructions below.

|                               | File Location / Command                  |
|-------------------------------|------------------------------------------|
| **Config File Path**          | `/var/lib/homebridge/config.json`        |
| **Storage Path**              | `/var/lib/homebridge`                    |
| **Restart Command**           | `sudo hb-service restart`                |
| **Stop Command**              | `sudo hb-service stop`                   |
| **Start Command**             | `sudo hb-service start`                  |
| **View Logs Command**         | `sudo hb-service logs`                   |
| **Systemd Service File**      | `/etc/systemd/system/homebridge.service` |
| **Systemd Env File**          | `/etc/default/homebridge`                |
| **Default SSH Username**      | `pi`                                     |
| **Default SSH Password**      | `raspberry`                              |

