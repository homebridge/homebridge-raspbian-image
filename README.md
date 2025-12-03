<p align="center">
<a href="https://github.com/homebridge/homebridge">
<img src="https://raw.githubusercontent.com/homebridge/branding/latest/logos/homebridge-color-round-stylized.png" height="150">
</a>
</p>

<span align="center">

# Homebridge Raspberry Pi Image

[![Build](https://github.com/homebridge/homebridge-raspbian-image/actions/workflows/create_raspbian_pi-gen.yml/badge.svg)](https://github.com/homebridge/homebridge-raspbian-image/actions/workflows/create_raspbian_pi-gen.yml)
[![GitHub release (latest by date)](https://badgen.net/github/release/homebridge/homebridge-raspbian-image?label=Version)](https://github.com/homebridge/homebridge-raspbian-image/releases/latest)
[![GitHub All Releases](https://img.shields.io/github/downloads/homebridge/homebridge-raspbian-image/total)](https://somsubhra.github.io/github-release-stats/?username=homebridge&repository=homebridge-raspbian-image&page=1&per_page=30)

</span>

This project provides a free [Raspbian](https://www.raspberrypi.org/downloads/raspbian/) based Raspberry Pi image with [Homebridge](https://github.com/homebridge/homebridge) and [Homebridge Config UI X](https://github.com/homebridge/homebridge-config-ui-x) pre-installed.

* Runs on RPI 2 or higher models supporting ARMv7 cpu's or greater ( Last version supporting RPI 1 and RPi Zero W was [v1.2.4](https://github.com/homebridge/homebridge-raspbian-image/releases/tag/v1.2.4))
* Built on Raspbian Lite (no desktop)
* Simple WiFi Setup
* Includes `ffmpeg` pre-compiled with audio support (libfdk-aac)
* Includes a user friendly, easy to use web based GUI to configure Homebridge and monitor your Raspberry Pi
* Visual configuration for over 400 plugins (no manual config.json editing required)

This image also provides a command called `hb-config` which helps you keep Node.js up-to-date, perform maintenance on your Homebridge server, and install additional optional software such as *[Pi Hole](https://github.com/homebridge/homebridge-raspbian-image/wiki/How-To-Install-Pi-Hole)* and *[deCONZ](https://github.com/homebridge/homebridge-raspbian-image/wiki/How-To-Install-deCONZ-for-ConBee-or-RaspBee)*.

The Homebridge service is installed using the method described in the official [Raspberry Pi Installation Guide](https://github.com/homebridge/homebridge/wiki/Install-Homebridge-on-Raspbian) on the [Homebridge](https://github.com/homebridge/homebridge) project wiki.

## Installation Instructions

<p align="center">
    <img src="./media/Raspbian Image.gif" width="600">
</p>

For full installation instructions, please refer to the [Homebridge Raspbian Image Wiki](https://github.com/homebridge/homebridge-raspbian-image/wiki/Getting-Started)

## Security and Privacy

* **Privacy:** The *Homebridge Raspbian Image*, as well as the [Homebridge](https://github.com/homebridge/homebridge) and [Homebridge Config UI X](https://github.com/homebridge/homebridge-config-ui-x) software components, do not contain any *analytics*, *call home*, or similar features that would allow the project maintainers to track you or the usage of this image.
* **Security:** The *Homebridge Raspbian Image* is kept up-to-date with the latest [official Raspbian builds](https://github.com/RPi-Distro/pi-gen). To find out more, or to report a security issue or vulnerability, please see the project's [SECURITY](.github/SECURITY.md) policy.
* **Transparency:** The *Homebridge Raspbian Image* project is open source and each image is built using the public GitHub Action runners. The build logs for each release are publicly available on the project's [GitHub Actions](https://github.com/homebridge/homebridge-raspbian-image/actions/workflows/main.yml) page and every release contains a SHA-256 checksum of the image you can use to verify the integrity of your download.

## Community

The official Homebridge Discord server and Reddit community are where users can discuss Homebridge and ask for help.

<span align="center">

[![Homebridge Discord](https://discordapp.com/api/guilds/432663330281226270/widget.png?style=banner2)](https://discord.gg/kqNCe2D) [![Homebridge Reddit](.github/homebridge-reddit.svg?sanitize=true)](https://www.reddit.com/r/homebridge/)

</span>

## Help

The *Homebridge Raspberry Pi Image* wiki contains more information and instructions on how to further customise your install:

https://github.com/homebridge/homebridge-raspbian-image/wiki
