#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== Linking Dotfiles ==="

DOTFILES_DIR="${HOME}/.dotfiles"
CONFIG_DIR="${HOME}/.config"

mkdir -p "$CONFIG_DIR"

link_file() {
  src="$1"
  dst="$2"
  if [ -e "$dst" ]; then
    echo "Skipping existing $dst"
  else
    ln -s "$src" "$dst"
    echo "Linked $dst"
  fi
}

# Example links
[ -d "$DOTFILES_DIR/config/nvim" ] && link_file "$DOTFILES_DIR/config/nvim" "$CONFIG_DIR/nvim"
[ -f "$DOTFILES_DIR/config/starship.toml" ] && link_file "$DOTFILES_DIR/config/starship.toml" "$CONFIG_DIR/starship.toml"

echo "Dotfiles linking complete."
