---
description: Install and manage AI CLI tools with mise plugins for reproducible, version-pinned tooling.
---

# Mise Plugins

**Status: Optional**

The `50-mise-plugins.sh` script installs [mise](https://mise.jdx.dev/) and registers local plugins for AI CLI tools. This enables reproducible, version-pinned tool management across machines.

## Managed Tools

| Plugin | Tool | Distribution |
|---|---|---|
| `ollama` | [Ollama](https://ollama.com/) | Binary from GitHub releases |
| `claude-code` | [Claude Code](https://claude.com/claude-code) | Native binary from release channel |
| `droid-factory` | [Droid (Factory AI)](https://factory.ai/) | Platform binary from Factory CDN |

## Features

- Installs mise via pacman if not already present
- Registers all local plugins from `mise-plugins/`
- Installs latest versions of each tool via mise
- Cross-platform architecture detection (x86_64/aarch64, Linux/macOS)
- WSL browser auth detection with `xdg-utils` hint
- Supports `--dry-run` for safe previewing

## Running

```bash
bash workstation/50-mise-plugins.sh            # Install mise + all AI tools
bash workstation/50-mise-plugins.sh --dry-run   # Preview without changes
```

## Architecture Detection

Each plugin detects your platform and CPU architecture automatically:

| Plugin | Linux x86_64 | Linux aarch64 | macOS |
|---|---|---|---|
| ollama | `ollama-linux-amd64.tgz` | `ollama-linux-arm64.tgz` | `Ollama-darwin.zip` |
| claude-code | `claude-linux-x64-*.tar.gz` | `claude-linux-arm64-*.tar.gz` | `claude-darwin-*` |
| droid-factory | `droid` (linux) | `droid` (linux) | `droid` (macos) |

## WSL Users

When running under WSL, the script detects Microsoft's kernel and reminds you to install browser auth prerequisites:

```bash
sudo pacman -S --needed xdg-utils
# For WSL browser forwarding, also install wslu from AUR
```

Set `BROWSER=wslview` in your shell profile so Claude Code and Droid can open your Windows browser for OAuth flows.

## Adding More Plugins

Create a directory under `mise-plugins/` with the standard structure:

```
mise-plugins/<tool>/bin/
├── list-all    # Output space-separated versions (oldest first)
├── download    # Download archive to $ASDF_DOWNLOAD_PATH
└── install     # Extract to $ASDF_INSTALL_PATH/bin/
```

Then add a `register_and_install <tool>` call in `workstation/50-mise-plugins.sh`.
