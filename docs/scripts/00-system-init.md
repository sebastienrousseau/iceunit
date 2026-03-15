---
description: Intelligent package synchronisation for Iceunit. Scans the local system and only installs missing dependencies for all project modules.
---

# System Initialization

**Status: Mandatory**

The `00-system-init.sh` script is the entry point for the Iceunit configuration.
 It ensures that all 50+ packages required by the hardware, dev, and security modules are present.

## How it Works

1. **Pre-flight Audit**: It uses `pacman -Qq` to scan your local database in milliseconds.
2. **Intelligent Skip**: If all required packages are already installed, it skips the network synchronization entirely.
3. **Conflict Resolution**: It automatically handles known file conflicts (e.g., untracked `ollama` directories) to ensure a smooth transaction.
4. **Optimized Sync**: It bundles all missing packages into a single `pacman` transaction to minimize database locks and disk I/O.

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
