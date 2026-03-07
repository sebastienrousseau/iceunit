---
description: Overview of CachyOS MacBook Air 2020 automation scripts with run order, design principles, and shell compatibility.
---

# Scripts Overview

All scripts live in the `scripts/` directory of the repository. They are numbered to indicate the recommended run order.

## Run Order

| Script | Purpose | Run As |
|---|---|---|
| [`00-setup-vault.sh`](/scripts/00-setup-vault) | First-time LUKS2 encrypted vault creation | `bash` |
| [`01-thermal-setup.sh`](/scripts/01-thermal-setup) | **Critical** — fix fan/thermal control | `sudo bash` |
| [`02-wifi-firmware.sh`](/scripts/02-wifi-firmware) | Wi-Fi & Bluetooth firmware management | `bash` |
| [`03-optimise.sh`](/scripts/03-optimise) | System-wide post-install optimisation | `sudo bash` |
| [`04-bootloader.sh`](/scripts/04-bootloader) | Limine management & rEFInd dual-boot | `sudo bash` |
| [`05-mount-vault.sh`](/scripts/05-mount-vault) | Unlock and mount the code vault | `bash` |
| [`06-unmount-vault.sh`](/scripts/06-unmount-vault) | Lock and unmount the code vault | `bash` |

## Design Principles

All scripts follow these conventions:

- **`#!/usr/bin/env bash`** — always run under bash, never rely on the calling shell
- **`set -euo pipefail`** — exit on error, undefined variables, or pipe failures
- **`find` instead of globs** — glob patterns (`applesmc.*`) fail in fish shell when called via `sudo bash`; all path discovery uses `find`
- **No `sudo -u` for AUR helpers** — `paru`/`yay` must run as the normal user; calling them via `sudo -u` inside a sudo session hangs indefinitely
- **Idempotent** — safe to run multiple times; existing configs are backed up, not overwritten blindly
- **Colour output** — consistent `[OK]`, `[INFO]`, `[WARN]`, `[ERROR]` prefixes

## Shell Compatibility Note

Scripts are invoked with `sudo bash scripts/01-thermal-setup.sh` — always specify `bash` explicitly. If you use fish shell and run `sudo scripts/01-thermal-setup.sh` without the `bash`, fish will try to execute it directly and glob patterns may still cause issues even with the shebang present.
