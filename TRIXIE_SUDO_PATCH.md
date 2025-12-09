# Trixie Sudo Permissions Patch

If you have already installed a Homebridge Raspberry Pi image and upgraded to Debian Trixie, you may experience issues with the restart/shutdown functionality in the Homebridge UI.

## Quick Fix (One-liner)

Run the following command to patch your existing installation:

```bash
curl -fsSL https://raw.githubusercontent.com/homebridge/homebridge-raspbian-image/latest/stage3_homebridge/01-homebridge/files/010_homebridge-nopasswd | sudo tee /etc/sudoers.d/010_homebridge-nopasswd > /dev/null && sudo chmod 0440 /etc/sudoers.d/010_homebridge-nopasswd && sudo visudo -c
```

### Alternative (if you prefer to see the content first):

```bash
sudo bash -c 'cat > /etc/sudoers.d/010_homebridge-nopasswd << "EOF"
# Allow homebridge user to run shutdown/reboot commands without password
# Both /sbin and /usr/sbin paths are included for compatibility across Debian versions
homebridge ALL=(root) NOPASSWD: /sbin/shutdown, /sbin/reboot, /sbin/poweroff, /usr/sbin/shutdown, /usr/sbin/reboot, /usr/sbin/poweroff
EOF
chmod 0440 /etc/sudoers.d/010_homebridge-nopasswd && visudo -c'
```

This command will:
1. Create the sudoers configuration file for the homebridge user
2. Set the correct permissions (0440)
3. Validate the sudoers syntax

## What This Fixes

This patch allows the homebridge user to run shutdown, reboot, and poweroff commands without requiring a password, which is necessary for the Homebridge UI's restart and shutdown features to work properly in Debian Trixie.

## Verification

After applying the patch, you can verify it worked by checking:

```bash
sudo -l -U homebridge
```

You should see output showing that the homebridge user can run shutdown, reboot, and poweroff commands without a password.
