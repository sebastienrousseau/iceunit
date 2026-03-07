---
description: 02-wifi-firmware.sh manages Broadcom BCM4377b Wi-Fi and Bluetooth firmware with verify, backup, restore, and install.
---

# 02-wifi-firmware.sh

Manages Broadcom BCM4377b Wi-Fi and BRCM4377 Bluetooth firmware for the MacBook Air 2020. Provides verification, backup, restore, and re-installation capabilities.

## Usage

```bash
# Interactive menu
bash scripts/02-wifi-firmware.sh

# Direct subcommands
bash scripts/02-wifi-firmware.sh verify
bash scripts/02-wifi-firmware.sh backup
sudo bash scripts/02-wifi-firmware.sh restore
sudo bash scripts/02-wifi-firmware.sh install-pkg
bash scripts/02-wifi-firmware.sh guide
```

## Subcommands

| Command | Root | Description |
|---|---|---|
| `verify` | No | Check that all required firmware files are present and test Wi-Fi/BT interfaces |
| `backup` | No | Copy firmware files to `~/.config/firmware-backup/brcm/` with a manifest |
| `restore` | Yes | Restore firmware from the backup directory and reload `brcmfmac` |
| `install-pkg` | Yes | Download and install the `apple-bcm-firmware` package from the arch-mact2 mirror |
| `guide` | No | Display the macOS firmware extraction guide for fresh installs |

## Firmware Files

The MacBook Air 2020 (board ID: `fiji`) requires:

| File | Purpose |
|---|---|
| `brcmfmac4377b3-pcie.apple,fiji.bin` | Wi-Fi firmware binary |
| `brcmfmac4377b3-pcie.apple,fiji.clm_blob` | Wi-Fi regulatory data |
| `brcmfmac4377b3-pcie.apple,fiji.txcap_blob` | Wi-Fi TX power caps |
| `brcmbt4377b3-apple,formosa.bin` | Bluetooth firmware |
| `brcmbt4377b3-apple,formosa.ptb` | Bluetooth patch RAM |

All files live in `/lib/firmware/brcm/`.

## Backup Location

Backups are stored at `~/.config/firmware-backup/brcm/` with a `MANIFEST.txt` listing file sizes and backup date.

## Files Modified

| Path | Purpose |
|---|---|
| `/lib/firmware/brcm/brcmfmac4377*` | Wi-Fi firmware (restore/install-pkg) |
| `/lib/firmware/brcm/brcmbt4377*` | Bluetooth firmware (restore/install-pkg) |
| `~/.config/firmware-backup/brcm/` | Backup directory (backup) |

## Prerequisites

- `curl` (for `install-pkg`)
- Internet connectivity (for `install-pkg`)
- Backup must exist before running `restore`

::: tip Source
View the full source on [GitHub](https://github.com/sebastienrousseau/cachyos-macbook-intel-2020/blob/main/scripts/02-wifi-firmware.sh).
:::
