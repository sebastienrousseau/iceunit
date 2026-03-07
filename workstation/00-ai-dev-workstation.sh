#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== AI Developer Workstation Setup (CachyOS / Arch) ==="

# Ensure pacman packages
sudo pacman -Sy --needed --noconfirm git curl wget base-devel ripgrep fd fzf bat eza jq yq neovim tmux zoxide atuin direnv starship docker docker-compose podman podman-compose python python-pip python-pipx nodejs npm go rust cmake ninja gcc clang mold lazygit github-cli ollama

# Enable docker if installed
if command -v docker >/dev/null 2>&1; then
  sudo systemctl enable --now docker || true
  sudo usermod -aG docker "$USER" || true
fi

# Python tools
pipx ensurepath
pipx install aider-chat || true
pipx install llm || true

# Node global dev tools
npm install -g typescript eslint prettier || true

echo "AI Developer Workstation setup complete."
