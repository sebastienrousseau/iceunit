---
description: Comprehensive AI development environment setup including Neovim, Docker, Podman, and Ollama.
---

# AI Dev Workstation

**Status: Optional**

The `00-ai-dev-workstation.sh` script provisions a professional AI developer environment.
 It focuses on performance, modern tooling, and seamless integration with CachyOS.

## Features

- **Editor**: Installs and configures Neovim with common dependencies.
- **Containers**: Set up both Docker and Podman (handled gracefully to avoid conflicts).
- **AI/LLM**: Installs Ollama for local LLM execution.
- **Language Runtimes**: Provisions Python (pipx), Node.js (npm), Go, and Rust.
- **CLI Tooling**: Installs high-productivity tools like `lazygit`, `fzf`, `ripgrep`, and `eza`.

## Running

```bash
# Usually run as part of the main installer
sudo make install

# Or run individually
sudo bash workstation/00-ai-dev-workstation.sh
```

## Resilience

The script is idempotent and system-aware. It uses `--needed` to skip already-installed packages and handles file conflicts automatically.
