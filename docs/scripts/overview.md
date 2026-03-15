---
description: Overview of CachyOS MacBook Air 2020 automation scripts with run order, design principles, and shell compatibility.
---

# Scripts Overview

All scripts live in the `scripts/` directory. They are numbered to indicate the recommended run order.

## Run Order

| Script | Purpose | Status | Run As |
|---|---|---|---|
| [`00-setup-vault.sh`](/scripts/00-setup-vault) | First-time LUKS2 encrypted vault creation | Optional | `make vault` |
| [`00-system-init.sh`](/scripts/00-system-init) | **Smart** — synchronise all required packages | **Mandatory** | `sudo make init` |
| [`01-thermal-setup.sh`](/scripts/01-thermal-setup) | **Critical** — fix fan/thermal control | **Mandatory** | `make thermal` |
| [`02-wifi-firmware.sh`](/scripts/02-wifi-firmware) | Wi-Fi & Bluetooth firmware management | **Mandatory** | `make wifi` |
| [`03-optimise.sh`](/scripts/03-optimise) | System-wide post-install optimisation | Recommended | `make optimise` |
| [`04-bootloader.sh`](/scripts/04-bootloader) | Limine management & rEFInd dual-boot | Recommended | `make bootloader` |
| [`05-mount-vault.sh`](/scripts/05-mount-vault) | Unlock and mount the code vault | Optional | `make mount` |
| [`06-unmount-vault.sh`](/scripts/06-unmount-vault) | Lock and unmount the code vault | Optional | `make unmount` |
| [`07-install-apps.sh`](/scripts/07-install-apps) | Standard application suite | Recommended | `make apps` |
| [`08-maintenance.sh`](/scripts/08-maintenance) | Periodic system maintenance | Recommended | `make maintenance` |
| [`99-verify-install.sh`](/scripts/99-verify-install) | **Audit** — verify system health | Recommended | `make verify` |

All scripts support dry-run mode: `make <target> DRY_RUN=1` (e.g. `make thermal DRY_RUN=1`).

## Design Principles

All scripts follow these conventions:

- **`#!/usr/bin/env bash`** — always run under bash, never rely on the calling shell
- **`set -euo pipefail`** — exit on error, undefined variables, or pipe failures
- **`--dry-run` flag** — every script supports `--dry-run` to preview changes without modifying the system
- **`--help` flag** — every script displays usage information with `--help`
- **`find` instead of globs** — glob patterns (`applesmc.*`) fail in fish shell when called via `sudo bash`; all path discovery uses `find`
- **Idempotent** — safe to run multiple times; existing configs are backed up, not overwritten blindly
- **Colour output** — consistent `[OK]`, `[INFO]`, `[WARN]`, `[ERROR]` prefixes

## Shell Compatibility Note

Use `make` targets to run scripts (e.g. `make thermal`). The Makefile handles `sudo` and `bash` automatically. If running scripts directly, use `sudo bash scripts/01-thermal-setup.sh` — always specify `bash` explicitly. If you use fish shell and run `sudo scripts/01-thermal-setup.sh` without the `bash`, fish will try to execute it directly and glob patterns may still cause issues even with the shebang present.

## Testing & Verification

The project includes an interactive Go-based installer (`make install`) and a comprehensive audit tool (`make verify`).

```bash
make verify             # Run the Iceunit system health audit
make test-all           # Run all tests (Lint, BATS, Go, Docker)
```

CI runs all checks automatically on every push and pull request.
