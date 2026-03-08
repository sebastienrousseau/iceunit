#!/usr/bin/env bash
set -Eeuo pipefail

DRY_RUN=false
ASSUME_YES=false
for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
    # shellcheck disable=SC2034
    [[ "$arg" == "--yes" ]] && ASSUME_YES=true
done

# Wrapper for destructive commands
dryrun() {
    if $DRY_RUN; then
        printf '\033[1;30m[DRY-RUN]\033[0m %s\n' "$*"
    else
        "$@"
    fi
}

log()   { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

log "=== Linking Dotfiles ==="

DOTFILES_DIR="${HOME}/.dotfiles"
CONFIG_DIR="${HOME}/.config"

dryrun mkdir -p "$CONFIG_DIR"

link_file() {
  src="$1"
  dst="$2"
  if [ -e "$dst" ]; then
    log "Skipping existing $dst"
  else
    dryrun ln -s "$src" "$dst"
    log "Linked $dst"
  fi
}

# Example links
[ -d "$DOTFILES_DIR/config/nvim" ] && link_file "$DOTFILES_DIR/config/nvim" "$CONFIG_DIR/nvim"
[ -f "$DOTFILES_DIR/config/starship.toml" ] && link_file "$DOTFILES_DIR/config/starship.toml" "$CONFIG_DIR/starship.toml"

log "Dotfiles linking complete."
