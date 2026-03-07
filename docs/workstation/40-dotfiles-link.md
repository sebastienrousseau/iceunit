---
description: Manage symbolic links for your personal dotfiles configuration.
---

# Dotfiles Link

**Status: Optional**

The `40-dotfiles-link.sh` script automates the creation of symbolic links from your local dotfiles repository to the system configuration directories.

## Functionality

- **Directory Mapping**: Links `~/.dotfiles/config/nvim` to `~/.config/nvim`.
- **Config Files**: Maps essential configurations like `starship.toml`.
- **Safety**: Checks for existing files before linking to prevent data loss.

## Running

```bash
bash workstation/40-dotfiles-link.sh
```

## Customization

You can easily extend this script to include your own specific dotfile mappings by adding `link_file` calls to the script.
