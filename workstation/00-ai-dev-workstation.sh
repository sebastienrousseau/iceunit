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
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
info()  { printf '\033[0;36m[INFO]\033[0m %s\n' "$*"; }

log "=== AI Developer Workstation Setup (CachyOS / Arch) ==="

# Ensure pacman packages (Split to handle conflicts gracefully)
PKGS=(git curl wget base-devel ripgrep fd fzf bat eza jq yq neovim tmux zoxide atuin direnv starship podman podman-compose python python-pip python-pipx nodejs npm go rust cmake ninja gcc clang mold lazygit github-cli ollama)
dryrun sudo pacman -Sy --needed --noconfirm --overwrite '/usr/share/ollama/*' "${PKGS[@]}"

# Install docker separately (often conflicts with podman-docker)
dryrun sudo pacman -S --needed --noconfirm docker docker-compose || warn "Docker installation skipped (possibly due to podman-docker conflict)"

# Enable docker or podman
if command -v docker >/dev/null 2>&1; then
  dryrun sudo systemctl enable --now docker || true
  REAL_USER="${SUDO_USER:-$USER}"
  dryrun sudo usermod -aG docker "$REAL_USER" || true
elif command -v podman >/dev/null 2>&1; then
  dryrun sudo systemctl enable --now podman.socket || true
fi

# Python tools
dryrun pipx ensurepath
dryrun pipx install aider-chat || true
dryrun pipx install llm || true

# Node global dev tools
dryrun npm install -g typescript eslint prettier || true

log "AI Developer Workstation setup complete."
