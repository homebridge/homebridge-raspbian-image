<p align="center">
<a href="https://github.com/homebridge/homebridge">
<img src="https://raw.githubusercontent.com/homebridge/branding/master/logos/homebridge-color-round-stylized.png" height="150">
</a>
</p>

<span align="center">

# Homebridge Raspberry Pi Image

[![Build](https://github.com/homebridge/homebridge-raspbian-image/workflows/CI/badge.svg)](https://github.com/homebridge/homebridge-raspbian-image/actions)
[![GitHub release (latest by date)](https://img.shields.io/github/v/release/homebridge/homebridge-raspbian-image?label=Version)](https://github.com/homebridge/homebridge-raspbian-image/releases/latest)

</span>

This project provides a free [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) based Raspberry Pi image with [Homebridge](https://github.com/nfarina/homebridge) and [Homebridge Config UI X](https://github.com/oznu/homebridge-config-ui-x) pre-installed.

* Works on all Raspberry Pi models
* Built on Raspbian Lite (no desktop)
* Simple WiFi Setup
* Includes `ffmpeg` pre-compiled with audio support (libfdk-aac) and hardware decoding (h264_omx)
* Includes a user friendly, easy to use web based GUI to configure Homebridge and monitor your Raspberry Pi
* Visual configuration for over 50 popular plugins (no manual config.json editing required)

This image also provides config command called `hb-config` which helps you keep Node.js up-to-date, perform maintentance on your Homebridge server, and install additional optional software such as *Pi Hole*, *Node-RED* and the *UniFI Controller*.

The Homebridge service is installed using the method described in the official [Raspberry Pi Installation Guide](https://github.com/nfarina/homebridge/wiki/Install-Homebridge-on-Raspbian) on the [Homebridge](https://github.com/nfarina/homebridge) project wiki.

## Download

Downloading the *Homebridge Raspberry Pi Image* is completely free (no sign up required).

<span align="center">
  
### [Download Latest Version](https://github.com/homebridge/homebridge-raspbian-image/releases/latest)
  
</span>

## Flash to SD Card

The easiest way to flash the *Homebridge Raspberry Pi Image* to your SD card is to use [Etcher](https://www.balena.io/etcher/).
  
<p align="center">
    <img src="https://user-images.githubusercontent.com/3979615/74733445-789cac00-52a0-11ea-9167-05b42d6383ad.gif" width="800">
</p>

1. Download and install the latest version of [Etcher](https://www.balena.io/etcher/).
2. Open Etcher and select the `Homebridge-Raspbian-v0.0.0.zip` file you have [downloaded](https://github.com/homebridge/homebridge-raspbian-image/releases/latest). There is no need to extract the `.zip` file first.
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

After a minute or so, use your phone to scan for new WiFi networks, you should to see a new WiFi hotspot named **Homebridge WiFi Setup**. Connecting to this hotspot will prompt you for the SSID and password for your local WiFi network.

If you enter your WiFi credentials incorrectly the **Homebridge WiFi Setup** hotspot will reappear allowing you to try again.

![wifi-connect-setup](https://user-images.githubusercontent.com/3979615/75397237-7e525b80-594a-11ea-9be0-4f064b6a4178.png)

## Managing Homebridge

The [Homebridge Config UI X](https://github.com/oznu/homebridge-config-ui-x) web interface will allow you to install, remove and update plugins, and modify the Homebridge config.json and manage other aspects of your Homebridge service.

**The default user is `admin` with password `admin`.**

If you're using macOS or a mobile device, you should be able to access the UI via http://homebridge.local.

If you're using Windows, or `http://homebridge.local` does not work for you, you will need to find the IP address of your Raspberry Pi another way:

1. Login to your router and find the "connected devices" or "dhcp clients" page to find the IP address that was assigned to the Raspberry Pi.
2. Use an iPhone to access `http://homebridge.local`, once you login using the default username and password (admin/admin) you can find the IP address under System Information.
3. Download the [Fing](https://www.fing.com/) app for [iOS](https://itunes.apple.com/us/app/fing-network-scanner/id430921107?mt=8) or [Android](https://play.google.com/store/apps/details?id=com.overlook.android.fing&hl=en_GB) to scan your network to find the IP address of your Raspberry Pi.
4. As a last resort, if you plug a monitor into your Raspberry Pi, the IP address will be displayed on the attached screen once it has finished booting.

Once you've found your IP address, login to the web interface by going to `http://<ip address of your server>`.

<p align="center">
  <img width="600px" src="https://user-images.githubusercontent.com/3979615/71886653-b16d3f80-3190-11ea-9ff8-49dc4ae4fff0.png">
</p>

You should take a moment to review the [Configuration Reference](#configuration-reference) at the bottom of this guide.

## Updating Node.js

To update Node.js run `sudo hb-config` and select **Upgrade Node.js**.

This will ensure your Raspberry Pi  is running the latest LTS version of Node.js.

<p align="center">
  <img width="600px" alt="hb-config" src="https://user-images.githubusercontent.com/3979615/74602581-4b17fd00-50fe-11ea-8684-c03eaa42d27d.png">
</p>

## SSH Access

SSH is enabled by default. The default username is `pi` with password `raspberry`.

* [How To Connect Via SSH](https://github.com/homebridge/homebridge-raspbian-image/wiki/How-To-Connect-Via-SSH)

## Security and Privacy

* **Privacy:** The *Homebridge Raspbian Image*, as well as the [Homebridge](https://github.com/nfarina/homebridge) and [Homebridge Config UI X](https://github.com/oznu/homebridge-config-ui-x) software components, do not contain any *analytics*, *call home*, or similar features that would allow the project maintainers to track you or the usage of this image.
* **Security:** The *Homebridge Raspbian Image* is kept up-to-date with the latest [offical Raspbian builds](https://github.com/RPi-Distro/pi-gen). To find out more, or to report a security issue or vulnerability, please see the project's [SECURITY](.github/SECURITY.md) policy.
* **Transparency:** The *Homebridge Raspbian Image* project is open source and each image is built using the public GitHub Action runners. The build logs for each release are publicly available on the project's [GitHub Actions](https://github.com/homebridge/homebridge-raspbian-image/actions) page and every release contains a SHA-256 checksum of the image you can use to verify the integrity of your download.

## Community

The official Homebridge Discord server and Reddit community are where users can discuss Homebridge and ask for help.

<span align="center">

[![Homebridge Discord](https://discordapp.com/api/guilds/432663330281226270/widget.png?style=banner2)](https://discord.gg/kqNCe2D) [![Homebridge Reddit](.github/homebridge-reddit.svg?sanitize=true)](https://www.reddit.com/r/homebridge/)

</span>

## Configuration Reference

This table contains important information about your setup. You can use the information provided here as a reference when configuring or troubleshooting your environment.

|                               | File Location / Command                  |
|-------------------------------|------------------------------------------|
| **Config File Path**          | `/var/lib/homebridge/config.json`        |
| **Storage Path**              | `/var/lib/homebridge`                    |
| **Restart Command**           | `sudo hb-service restart`                |
| **Stop Command**              | `sudo hb-service stop`                   |
| **Start Command**             | `sudo hb-service start`                  |
| **View Logs Command**         | `sudo hb-service logs`                   |
| **Manage Homebridge Server**  | `sudo hb-config`                         |
| **Systemd Service File**      | `/etc/systemd/system/homebridge.service` |
| **Systemd Env File**          | `/etc/default/homebridge`                |
| **Default Hostname**          | `homebridge.local`                       |
| **Default SSH Username**      | `pi`                                     |
| **Default SSH Password**      | `raspberry`                              |
| **Default Web Username**      | `admin`                                  |
| **Default Web Password**      | `admin`                                  |

The *Homebridge Raspberry Pi Image* wiki contains more information and instructions on how to further customise your install:

https://github.com/homebridge/homebridge-raspbian-image/wiki
