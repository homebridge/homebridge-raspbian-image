# Trixie Sudo Permissions Patch

This patch is for images **v1.4.0, v1.4.1 and v1.4.2** (built between 3 and 8 December 2025). On those images the "Restart / Shut Down Server" buttons in the Homebridge UI do not work.

* Newer images already have this fix. You do not need to do anything.
* Older images (before v1.4.0) do not need it either: there Homebridge runs as the first user (`pi`), which may already use `sudo`.

How to check if you need it (run over SSH):

```bash
systemctl show -p User --value homebridge   # prints "homebridge" on the affected images
ls /etc/sudoers.d/010_homebridge-nopasswd   # "No such file" means the fix is missing
```

## Quick Fix (One-liner)

**You can not apply this fix using the Homebridge UI web terminal! Login using SSH instead.**
<BR>
Run the following command from ssh to patch your existing installation:

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

This patch allows the homebridge user to run shutdown, reboot, and poweroff commands without requiring a password, which is necessary for the Homebridge UI's restart and shutdown features to work. It gives the homebridge user no other rights.

## Verification

After applying the patch, you can verify it worked by checking:

```bash
sudo -l -U homebridge
```

You should see output showing that the homebridge user can run shutdown, reboot, and poweroff commands without a password.
