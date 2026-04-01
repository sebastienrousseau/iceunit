---
description: 08-maintenance.sh performs periodic maintenance including system upgrades, T2 health checks, SSD TRIM, cache cleanup, and bootloader integrity verification.
verifiedOn: 2026-04-01
---

# 08-maintenance.sh

**Status: Recommended**

Periodic maintenance script for keeping your MacBook Air 2020 (MacBookAir9,1) running CachyOS in healthy shape. It covers system upgrades, T2 hardware checks, storage maintenance, and developer environment readiness.

## Usage

```bash
sudo bash scripts/08-maintenance.sh [--dry-run] [--help]
```

| Flag | Description |
|---|---|
| `--dry-run` | Preview all actions without modifying the system |
| `--help` | Show usage information and exit |

## What It Does

1. **System Upgrade** — ranks mirrors (skipped if mirrorlist is less than 24 hours old), then runs a full `paru -Syu` (or `yay`/`pacman` fallback) as the real user via `runuser`.
2. **T2 Hardware Health** — read-only checks: `apple_bce` module loaded, `mbpfan` service active, fan speed from sysfs.
3. **SSD TRIM** — runs `fstrim -va` on all mounted volumes.
4. **Package Cache Cleanup** — keeps 2 versions of installed packages (`paccache -rk2`) and removes all cached uninstalled packages (`paccache -ruk0`). Skips gracefully if `paccache` is not installed.
5. **Orphan Removal** — detects and removes orphaned packages (`pacman -Qtdq`). Skips if none found.
6. **Failed Systemd Units** — read-only scan for any failed units.
7. **Journal Vacuum** — cleans journal entries older than 3 days.
8. **Limine Bootloader Integrity** — read-only verification of `limine.conf`, kernel entry, and `limine-entry-tool` availability.
9. **Git Signing Readiness** — read-only check of GPG agent, signing key, and `commit.gpgsign` for the real user.

## Prerequisites

- Root access (run with `sudo` or via `make maintenance`).
- An AUR helper (`paru` or `yay`) for system upgrades.
- `pacman-contrib` for package cache cleanup (`paccache`).

::: tip Source
View the full source on [GitHub](https://github.com/sebastienrousseau/iceunit/blob/main/scripts/08-maintenance.sh).
:::
