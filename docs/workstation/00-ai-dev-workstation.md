---
description: Comprehensive AI development environment setup including Neovim, Docker, Podman, and Ollama.
verifiedOn: 2026-04-01
---

# AI Dev Workstation

**Status: Optional**

The `00-ai-dev-workstation.sh` script provisions an AI development environment. It focuses on performance, modern tooling, and native integration with CachyOS.

## Packages Installed

| Category | Packages |
|----------|----------|
| Build Tools | `base-devel`, `cmake`, `ninja`, `gcc`, `clang`, `mold` |
| CLI Utilities | `ripgrep`, `fd`, `fzf`, `bat`, `eza`, `jq`, `yq` |
| Terminal | `neovim`, `tmux`, `zoxide`, `atuin`, `direnv`, `starship` |
| Containers | `podman`, `podman-compose` (Docker attempted with conflict fallback) |
| Language Runtimes | `python`, `python-pip`, `python-pipx`, `nodejs`, `npm`, `go`, `rust` |
| AI/LLM | `ollama` |
| Git | `lazygit`, `github-cli` |

All packages are installed via `pacman --needed --noconfirm`, so re-running the script is safe and skips anything already present.

## Python Tools (via pipx)

After base packages are installed the script uses `pipx` to set up isolated Python CLI tools:

- **aider-chat** — AI pair-programming assistant that works with local and remote models.
- **llm** — command-line interface for interacting with large language models.

## Node.js Globals (via npm)

The following are installed globally through `npm`:

- **typescript** — TypeScript compiler.
- **eslint** — JavaScript/TypeScript linter.
- **prettier** — opinionated code formatter.

## Container Runtime

The script attempts to install Docker first. If Docker's packages conflict with existing Podman files (a common situation on CachyOS), the script catches the error and falls back gracefully to Podman with socket activation. This means `docker` CLI commands continue to work transparently through the Podman compatibility socket.

## Running

```bash
# Usually run as part of the main installer
sudo make install

# Or run individually
sudo bash workstation/00-ai-dev-workstation.sh
```

## Resilience

The script is idempotent and system-aware. It uses `--needed` to skip already-installed packages and handles file conflicts automatically.

::: tip Source
View the full source on [GitHub](https://github.com/sebastienrousseau/iceunit/blob/main/workstation/00-ai-dev-workstation.sh).
:::
