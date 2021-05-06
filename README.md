<p align="center">
<a href="https://github.com/homebridge/homebridge">
<img src="https://raw.githubusercontent.com/homebridge/branding/master/logos/homebridge-color-round-stylized.png" height="150">
</a>
</p>

<span align="center">

# Homebridge Raspberry Pi Image

[![Build](https://github.com/homebridge/homebridge-raspbian-image/workflows/CI/badge.svg)](https://github.com/homebridge/homebridge-raspbian-image/actions)
[![GitHub release (latest by date)](https://badgen.net/github/release/homebridge/homebridge-raspbian-image?label=Version)](https://github.com/homebridge/homebridge-raspbian-image/releases/latest)
[![GitHub All Releases](https://img.shields.io/github/downloads/homebridge/homebridge-raspbian-image/total)](https://somsubhra.github.io/github-release-stats/?username=homebridge&repository=homebridge-raspbian-image&page=1&per_page=30)

</span>

This project provides a free [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) based Raspberry Pi image with [Homebridge](https://github.com/nfarina/homebridge) and [Homebridge Config UI X](https://github.com/oznu/homebridge-config-ui-x) pre-installed.

* Works on all Raspberry Pi models
* Built on Raspbian Lite (no desktop)
* Simple WiFi Setup
* Includes `ffmpeg` pre-compiled with audio support (libfdk-aac) and hardware decoding (h264_omx)
* Includes a user friendly, easy to use web based GUI to configure Homebridge and monitor your Raspberry Pi
* Visual configuration for over 400 plugins (no manual config.json editing required)

This image also provides a command called `hb-config` which helps you keep Node.js up-to-date, perform maintenance on your Homebridge server, and install additional optional software such as *[Pi Hole](https://github.com/homebridge/homebridge-raspbian-image/wiki/How-To-Install-Pi-Hole)*, *[deCONZ](https://github.com/homebridge/homebridge-raspbian-image/wiki/How-To-Install-deCONZ-for-ConBee-or-RaspBee)*, *Node-RED* and the *UniFI Controller*.

The Homebridge service is installed using the method described in the official [Raspberry Pi Installation Guide](https://github.com/nfarina/homebridge/wiki/Install-Homebridge-on-Raspbian) on the [Homebridge](https://github.com/homebridge/homebridge) project wiki.

## Download and Flash to SD Card

The *Homebridge Raspberry Pi Image* is completely free (no sign up required).

The easiest way to flash the *Homebridge Raspberry Pi Image* to your SD card is to use the [Raspberry Pi Imager](https://www.raspberrypi.org/software/).

<p align="center">
    <img src="https://user-images.githubusercontent.com/3979615/117293909-58f99f80-aeb5-11eb-922c-37029f071481.gif" width="600">
</p>

1. Download and install the latest version of [Raspberry Pi Imager](https://www.raspberrypi.org/software/).
2. Open the *Raspberry Pi Imager* application.
3. Click **Choose OS**.
4. Scroll down and select the **Other specific purpose OS** category.
5. Select **Homebridge**, then choose the latest Homebridge image.
6. Click **Choose Storage** and select your SD card.
7. Click **Write**.

*Raspberry Pi Imager* will now download and flash the latest version of the *Homebridge Raspberry Pi Image* to your SD card, this may take several minutes depending on the speed of your internet connection and SD card.

---

**Advanced users:**

If you wish to use another tool such as [Etcher](https://www.balena.io/etcher/) or [`dd`](https://www.raspberrypi.org/documentation/installation/installing-images/mac.md) to flash the Homebridge Raspberry Pi Image, you can manually download the image from our releases page:

<span align="center">

### [Download Latest Version](https://github.com/homebridge/homebridge-raspbian-image/releases/latest)

</span>

## First Boot / Network Setup

Now that you have flashed your SD card, you can insert it into your Raspberry Pi.

Before powering on your Raspberry Pi decide if you want to use Ethernet or WiFi to connect to your network.

### Ethernet

**:warning: An Ethernet connection is recommended as this provides the most simple and stable Homebridge setup.**

If you have decided to connect your Raspberry Pi using ethernet, do so before you power on your device for the first time. 

### WiFi Setup

Follow these steps to connect your device to WiFi:

1. Power on your device without an Ethernet cable attached.
2. Wait 1-2 minutes
3. Use your mobile phone to scan for new WiFi networks
4. Connect to the hotspot named **Homebridge WiFi Setup**
5. Wait a few moments until the captive portal opens, this portal will allow you to connect the Raspberry Pi to your local WiFi network.

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
  <img width="600px" alt="hb-config" src="https://user-images.githubusercontent.com/3979615/97378609-d8ab1e00-1916-11eb-8e9e-ec1d399bfa4b.png">
</p>

## SSH Access

SSH is enabled by default. The default username is `pi` with password `raspberry`.

* [How To Connect Via SSH](https://github.com/homebridge/homebridge-raspbian-image/wiki/How-To-Connect-Via-SSH)

## Security and Privacy

* **Privacy:** The *Homebridge Raspbian Image*, as well as the [Homebridge](https://github.com/nfarina/homebridge) and [Homebridge Config UI X](https://github.com/oznu/homebridge-config-ui-x) software components, do not contain any *analytics*, *call home*, or similar features that would allow the project maintainers to track you or the usage of this image.
* **Security:** The *Homebridge Raspbian Image* is kept up-to-date with the latest [official Raspbian builds](https://github.com/RPi-Distro/pi-gen). To find out more, or to report a security issue or vulnerability, please see the project's [SECURITY](.github/SECURITY.md) policy.
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