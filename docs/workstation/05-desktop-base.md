---
description: 05-desktop-base.sh installs and enables the desktop foundation — GNOME, GDM, fonts, firmware updates, CPU microcode, Bluetooth, system timers, and essential utilities.
verifiedOn: 2026-04-01
---

# 05-desktop-base.sh

**Status: Recommended**

Desktop foundation script that bridges the gap between core hardware setup (scripts 00–08) and workstation provisioning modules. Ensures the desktop environment, display manager, fonts, firmware updater, and essential timers are fully installed and enabled.

## Usage

```bash
sudo bash workstation/05-desktop-base.sh [--dry-run] [--help]
```

| Flag | Description |
|---|---|
| `--dry-run` | Preview all actions without modifying the system |
| `--help` | Show usage information and exit |

## What It Does

1. **Desktop Environment** — installs `gnome` and `gdm` if not already present.
2. **NetworkManager** — installs and enables `NetworkManager` for network connectivity.
3. **Audio Stack (PipeWire)** — installs `pipewire`, `pipewire-pulse`, and `wireplumber` for modern GNOME audio.
4. **XDG User Directories** — installs `xdg-user-dirs` and runs `xdg-user-dirs-update` to create standard folders.
5. **Fonts** — installs `noto-fonts`, `noto-fonts-emoji`, `ttf-dejavu`, and `ttf-liberation`.
6. **Firmware Updates** — installs and enables `fwupd.service` for firmware update management.
7. **CPU Microcode** — installs `intel-ucode` for Intel Ice Lake microcode updates.
8. **Maintenance Utilities** — installs `pacman-contrib` (provides `paccache` and `checkupdates`).
9. **System Timers** — enables `fstrim.timer` (periodic SSD TRIM) and `paccache.timer` (weekly cache cleanup).
10. **Bluetooth Service** — installs `bluez`/`bluez-utils` and enables `bluetooth.service`.
11. **Display Manager** — enables `gdm` to start on boot.

## Prerequisites

- Root access (run with `sudo` or via `make desktop`).
- An active internet connection for package installation.

::: tip Source
View the full source on [GitHub](https://github.com/sebastienrousseau/iceunit/blob/main/workstation/05-desktop-base.sh).
:::
