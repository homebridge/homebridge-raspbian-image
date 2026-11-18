# userconf patches

These two patches change the Raspberry Pi OS "first boot" user setup (`userconf-pi`).

- **What they do:** they refuse a user name that already exists on the image.
  - Example: a user types `homebridge` as their user name in Raspberry Pi Imager. Without the
    patches the setup would try to rename the first user to `homebridge`, a user the image already
    has for the Homebridge service, and the first boot would break.
- **Why they are here:** the same change was offered to Raspberry Pi in
  https://github.com/RPi-Distro/userconf-pi/pull/11. That pull request was closed without a merge,
  so the patches are still needed.
- **When to remove them:** only if `userconf-pi` itself starts to refuse existing user names.
- pi-gen applies the files in `00-patches/` in the order listed in `00-patches/series`.
