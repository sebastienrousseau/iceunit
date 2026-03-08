---
description: 07-install-apps.sh provisions a standard suite of common applications including browsers, media players, and system tools for CachyOS.
---

# 07-install-apps.sh

**Status: Recommended**

Provisions a standard suite of common applications for daily use. It is system-aware and uses AUR helpers (`paru` or `yay`) where necessary to install packages like Google Chrome.

## Usage

```bash
bash scripts/07-install-apps.sh [--dry-run] [--help]
```

| Flag | Description |
|---|---|
| `--dry-run` | Preview all actions without modifying the system |
| `--help` | Show usage information and exit |

## What It Does

1. **Smart Check** — uses `pacman -Qq` to identify which applications are already installed.
2. **Idempotent Skip** — if all apps are present, it exits immediately.
3. **AUR Helper Detection** — identifies if `paru` or `yay` is available to handle non-official packages.
4. **Surgical Install** — installs only the missing applications in a single transaction.

## Application Suite

The script manages the following standard applications:
- **Browsers**: `google-chrome`, `brave-bin`.
- **Media**: `vlc`, `loupe` (Image viewer).
- **Editor**: `zed`, `ghostty`.
- **System**: `nautilus`, `virt-manager`, `extension-manager`, `gnome-screenshot`.
- **Office**: `libreoffice-fresh`.

## Prerequisites

- Internet connectivity.
- An AUR helper (`paru` recommended) for Chrome/Zed if they are not in your configured repositories.

::: tip Source
View the full source on [GitHub](https://github.com/sebastienrousseau/cachyos-macbook-intel-2020/blob/main/scripts/07-install-apps.sh).
:::
