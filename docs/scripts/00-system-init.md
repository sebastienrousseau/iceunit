---
description: Intelligent package synchronisation for Iceunit. Scans the local system and only installs missing dependencies for all project modules.
verifiedOn: 2026-04-01
---

# System Initialization

**Status: Mandatory**

The `00-system-init.sh` script is the entry point for the Iceunit configuration.
 It ensures that all 50+ packages required by the hardware, dev, and security modules are present.

## How it Works

1. **Pre-flight Audit**: It batch-queries `pacman -Qq` with all package names in a single fork, then builds an associative-array lookup to identify missing packages in O(1) per package.
2. **Intelligent Skip**: If all required packages are already installed, it skips the network synchronisation entirely.
3. **Mirror Ranking**: Skips ranking if the mirrorlist was refreshed within the last 24 hours. Otherwise, ranks mirrors using `cachyos-rate-mirrors`, `rate-mirrors`, or `reflector` (whichever is available) for faster downloads.
4. **Conflict Resolution**: It automatically handles known file conflicts (e.g., untracked `ollama` directories) to ensure a smooth transaction.
5. **Optimised Sync**: It bundles all missing packages into a single `pacman` transaction to minimise database locks and disk I/O.

## Usage

```bash
bash scripts/00-system-init.sh [--dry-run] [--yes] [--help]
```

| Flag | Description |
|---|---|
| `--dry-run` | Preview actions without modifying the system |
| `--yes` | Skip confirmation prompts |
| `--help` | Display usage information |

## Running

```bash
# Usually run as part of the main installer
sudo make install

# Or run individually
sudo make init
```

## Package List

The script manages a comprehensive stack including:
- **Core Hardware**: `mbpfan`, `tlp`, `pipewire`, `limine`, `snapper`, `cryptsetup`.
- **AI Dev Stack**: `neovim`, `docker`, `podman`, `python`, `nodejs`, `rust`, `go`, `ollama`.
- **Tooling**: `kubectl`, `terraform`, `ansible`, `gitleaks`, `sops`, `ufw`.
