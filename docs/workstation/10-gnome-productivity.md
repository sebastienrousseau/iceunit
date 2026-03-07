---
description: Optimise GNOME desktop for maximum productivity by disabling animations and setting focus-mode.
---

# GNOME Productivity

**Status: Optional**

The `10-gnome-productivity.sh` script applies a set of productivity-focused GNOME shell tweaks to make the desktop experience faster and more efficient.

## Tweaks Applied

- **Animations**: Disables UI animations for an "instant" feel.
- **Focus Mode**: Sets focus-follows-mouse (sloppy) for faster window switching.
- **Workspaces**: Configures `Super + 1/2/3` shortcuts for instant workspace switching.
- **Terminal**: Maps `Super + Return` to launch the terminal.

## Running

```bash
# Usually run as part of the main installer
make install

# Or run individually
bash workstation/10-gnome-productivity.sh
```

## Note

This script uses `gsettings` and should be run as your normal user (the installer handles this automatically).
