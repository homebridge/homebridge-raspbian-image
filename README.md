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

This project provides a free [Raspberry Pi OS](https://www.raspberrypi.com/software/operating-systems/) based Raspberry Pi image with [Homebridge](https://github.com/homebridge/homebridge) and the [Homebridge UI](https://github.com/homebridge/homebridge-config-ui-x) pre-installed.

* Runs on the Raspberry Pi 2 or later (the 64-bit image is recommended for the Pi 3 and later). The last version supporting the Raspberry Pi 1 and Pi Zero W was [v1.2.4](https://github.com/homebridge/homebridge-raspbian-image/releases/tag/v1.2.4)
* Built on Raspberry Pi OS Lite, based on Debian 13 "Trixie" (no desktop)
* Simple WiFi Setup
* Includes [ffmpeg](https://github.com/homebridge/ffmpeg-for-homebridge) pre-compiled with audio support (libfdk-aac)
* Includes a user friendly, easy to use web based GUI to configure Homebridge and monitor your Raspberry Pi
* Visual configuration for over 400 plugins (no manual config.json editing required)

This image also provides a command called `hb-config` which helps you keep Node.js up-to-date, perform maintenance on your Homebridge server, and install additional optional software such as *[Pi-hole](https://github.com/homebridge/homebridge-raspbian-image/wiki/How-To-Install-Pi-Hole)* and AdGuard Home.

The Homebridge service is installed using the method described in the official [Raspberry Pi Installation Guide](https://github.com/homebridge/homebridge/wiki/Install-Homebridge-on-Raspbian) on the [Homebridge](https://github.com/homebridge/homebridge) project wiki.

## Installation Instructions

<p align="center">
    <img src="./media/Raspbian Image.gif" width="600">
</p>

For full installation instructions, please refer to the [Homebridge Raspbian Image Wiki](https://github.com/homebridge/homebridge-raspbian-image/wiki/Getting-Started)

## Security and Privacy

* **Privacy:** The *Homebridge Raspbian Image*, as well as the [Homebridge](https://github.com/homebridge/homebridge) and [Homebridge UI](https://github.com/homebridge/homebridge-config-ui-x) software components, do not contain any *analytics*, *call home*, or similar features that would allow the project maintainers to track you or the usage of this image.
* **Security:** The *Homebridge Raspbian Image* is kept up-to-date with the latest [official Raspberry Pi OS builds](https://github.com/RPi-Distro/pi-gen). To find out more, or to report a security issue or vulnerability, please see the project's [SECURITY](.github/SECURITY.md) policy.
* **Transparency:** The *Homebridge Raspbian Image* project is open source and each image is built using the public GitHub Action runners. The build logs for each release are publicly available on the project's [GitHub Actions](https://github.com/homebridge/homebridge-raspbian-image/actions/workflows/create_raspbian_pi-gen.yml) page. Every release has a file called `rpi-image-repo.json` with SHA-256 checksums you can use to verify the integrity of your download: `image_download_sha256` is the checksum of the `.zip` file, and `extract_sha256` is the checksum of the `.img` file inside it.

## Community

The official Homebridge Discord server and Reddit community are where users can discuss Homebridge and ask for help.

<span align="center">

[![Homebridge Discord](https://discordapp.com/api/guilds/432663330281226270/widget.png?style=banner2)](https://discord.gg/kqNCe2D) [![Homebridge Reddit](.github/homebridge-reddit.svg?sanitize=true)](https://www.reddit.com/r/homebridge/)

</span>

## Help

The *Homebridge Raspberry Pi Image* wiki contains more information and instructions on how to further customise your install:

https://github.com/homebridge/homebridge-raspbian-image/wiki

## For Maintainers

### What is in this repo

| Path | What it is |
| ---- | ---------- |
| `stage3_homebridge/` | The build steps that turn Raspberry Pi OS Lite into the Homebridge image. [pi-gen](https://github.com/RPi-Distro/pi-gen) (the Raspberry Pi OS build tool) runs them after its own stages 0 to 2. |
| `stable/package.json` | The exact versions the image is built from: the Homebridge apt package, ffmpeg and wifi-connect. The dependency bot keeps it up to date. |
| `scripts/` | Helper scripts for the build and the release. Each one says what it does at its top. |
| `tests/` | Tests for the scripts. See [tests/README.md](tests/README.md). |
| `.github/workflows/` | The release workflows (below) and the pull request checks (`ci.yml`). |

### How a release is made

Releases are automatic. Nobody has to press a button.

1. **Stage 1** (`release-stage-1_update_dependencies.yml`) runs every day.
   - The dependency bot looks for new versions of the packages in `stable/package.json` and pushes them to `latest`.
   - If there are new versions, or versions on the branch that were never released, it starts Stage 2 and waits for it.
   - Stage 1 shows red when the build or the release fails.
2. **Stage 2** (`create_raspbian_pi-gen.yml`) builds the 32-bit and the 64-bit image.
   - It then **checks each image** (`scripts/check-image.sh`): Homebridge, Node.js, the services and the versions must be in the image, and Node.js must run.
   - If a check fails, the run stops here. No release is made.
   - Then it starts Stage 3 and waits for it.
3. **Stage 3** (`release-stage-3_package_release.yml`) makes the GitHub release, with the tag on the commit that was built.
   - Last, it updates `rpi-image-repo.json` on [homebridge.io](https://homebridge.io/rpi-image-repo.json). **Raspberry Pi Imager reads that file**, so this is the step that puts a new image in front of every Imager user.
   - That file is only updated when both images passed the image check, and the file itself passed `scripts/check-imager-json.py`.

To start a build by hand, run Stage 1 or Stage 2 from the Actions page. With `publish` off, the release is marked as a pre-release and the Imager list is not touched.

Things other projects depend on, which must not change by accident:

* the fields of `rpi-image-repo.json` (`scripts/check-imager-json.py` lists them), and `init_format: systemd` together with `enable-cloud-init: 0` in the build;
* the names of the release files (`image_<date>-Homebridge-trixie-<32bit|64bit>.zip`, `homebridge_raspbian_image_<arm64|armhf>.manifest`, `rpi-image-repo.json`);
* three files that Raspberry Pis in the field download from the `latest` branch: `stage3_homebridge/01-homebridge/files/hb-config` (old images), `.../hb-config-new` (images before v2.0.26) and `.../010_homebridge-nopasswd`.

### Build an image on your own machine

You need Docker, `git`, `jq` and `curl`.

```sh
./setup_local_test_environment.sh 64bit   # or 32bit
./pi-gen/build-docker.sh
```

The image is written to `pi-gen/deploy/`. A full build takes a long time and several GB of disk.

### Tests

```sh
tests/run.sh
```

The tests need Linux. [tests/README.md](tests/README.md) shows how to run them in a container on a Mac. They also run on every pull request, together with `shellcheck` and `actionlint`.
