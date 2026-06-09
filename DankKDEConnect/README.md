# DankKDEConnect / Phone Connect Plugin

Connect your phone to your desktop. Supports both KDE Connect and Valent backends.

## Requirements

### For KDE Connect

**Packages:**

- `kdeconnect` - the daemon and tools
- `sshfs` - for file browsing

**File Browser Setup:**

KDE Connect uses `kdeconnect://` URIs which only works with dolphin:

```bash
# For Dolphin (KDE)
xdg-mime default org.kde.dolphin.desktop x-scheme-handler/kdeconnect
```

**Start the daemon:**

```bash
/usr/lib/kdeconnect/kdeconnectd
```

You can start at niri startup in `~/.config/niri/config.kdl`

```kdl
spawn-at-startup "kdeconnectd"
```

### For Valent

**Packages:**

- `valent` - the daemon (AUR: `valent`)
- `gvfs` - for SFTP mounting
- `gvfs-mtp` or `gvfs-backends` - GVfs backends including SFTP
- `openssh` - for SSH agent

**SFTP Requirements:**

Valent uses GVfs for SFTP mounting. Before mounting, it registers an SSH key with your SSH agent using `ssh-add`.

**SSH Agent Setup (required for SFTP):**

newer gnome-keyring moved SSH agent to a separate service. Enable it:

```bash
systemctl --user enable --now gcr-ssh-agent.socket
```

Add to `~/.zshenv` or `~/.profile`:

```bash
export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
```

Verify it works:

```bash
echo $SSH_AUTH_SOCK  # should show /run/user/1000/gcr/ssh
ssh-add -l           # should connect without error
```

**Start the daemon:**

```bash
valent --gapplication-service
# or via systemd:
systemctl --user enable --now valent
```

**Known issue:**

- Valent clipboard sync may fail silently on some Wayland compositors unless Valent is focused. Text/file sharing is unaffected.

**Niri example** (`~/.config/niri/config.kdl`):

```kdl
environment {
    SSH_AUTH_SOCK "/run/user/1000/gcr/ssh"
}

spawn-at-startup "systemctl" "--user" "import-environment" "SSH_AUTH_SOCK"
spawn-at-startup "valent" "--gapplication-service"
```

## Phone Setup

Install **KDE Connect** on your phone (Android/iOS). Both KDE Connect and Valent on desktop are compatible with the same phone app.

1. Open KDE Connect on phone
2. Ensure phone and desktop are on same network
3. Pair the devices
4. Grant permissions for features you want (files, notifications, etc.)

## Features

- View phone battery level and charging status
- Ring phone to find it
- Send ping notifications
- Share clipboard
- Browse phone files (SFTP)
- Send SMS

## Troubleshooting

**Device not appearing:**

- Check both devices are on same network
- Restart the daemon
- Check firewall (ports 1714-1764 UDP/TCP)

**SFTP not working (Valent):**

- Check SSH agent: `echo $SSH_AUTH_SOCK` (must not be empty)
- If "Failed to add host key" error: SSH agent isn't running or accessible
- Run `gio mount -l` to check if mount exists
- Check Valent logs: `journalctl --user -u valent -f`
- Manually test: `gio mount sftp://PHONE_IP:1739/`

**SFTP not working (KDE Connect):**

- Ensure `sshfs` is installed
- Set xdg-mime handler (see above)
- Check `kdeconnect-cli -l` shows device

**Battery not showing:**

- Ensure device is paired AND connected
- Check battery permission granted on phone
