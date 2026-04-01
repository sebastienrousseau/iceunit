---
description: Manage symbolic links for your personal dotfiles configuration.
verifiedOn: 2026-04-01
---

# Dotfiles Link

**Status: Optional**

The `40-dotfiles-link.sh` script automates the creation of symbolic links from your local dotfiles repository to the system configuration directories.

## How It Works

1. Checks that `~/.dotfiles` exists. If missing, the script exits with a warning.
2. Creates `~/.config` if it does not already exist.
3. Calls `link_file()` for each mapping listed below. `link_file` accepts a source path and a destination path.

## Current Mappings

| Source | Destination | Type |
|--------|-------------|------|
| `~/.dotfiles/config/nvim` | `~/.config/nvim` | Directory |
| `~/.dotfiles/config/starship.toml` | `~/.config/starship.toml` | File |

## Safety

The `link_file` helper never overwrites existing files or directories. Before creating a symlink it checks whether the destination already exists — if it does, the link is skipped and a timestamped log message records the decision. This means you can re-run the script at any time without risking data loss.

## Running

```bash
bash workstation/40-dotfiles-link.sh
```

## Adding Your Own

To link additional dotfiles, add a `link_file` call to the script:

```bash
link_file "$HOME/.dotfiles/config/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
```

The function handles directory creation, existence checks, and logging automatically.

::: tip Source
View the full source on [GitHub](https://github.com/sebastienrousseau/iceunit/blob/main/workstation/40-dotfiles-link.sh).
:::
