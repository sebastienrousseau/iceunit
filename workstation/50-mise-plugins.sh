#!/usr/bin/env bash
set -Eeuo pipefail

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help)
            echo "Usage: bash workstation/50-mise-plugins.sh [--dry-run] [--help]"
            echo "Install mise and register local AI tool plugins."
            exit 0
            ;;
    esac
done

# ── Helpers ──────────────────────────────────────────────────────────────────

dryrun() {
    if $DRY_RUN; then
        printf '\033[1;30m[DRY-RUN]\033[0m %s\n' "$*"
    else
        "$@"
    fi
}

log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m %s\n' "$*"; }
info() { printf '\033[1;34m[INFO]\033[0m %s\n' "$*"; }

# ── Resolve paths ────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
PLUGINS_DIR="${REPO_DIR}/mise-plugins"

log "=== Mise Plugin Infrastructure ==="

# ── Install mise ─────────────────────────────────────────────────────────────

if command -v mise >/dev/null 2>&1; then
    info "mise already installed: $(mise --version)"
else
    log "Installing mise via pacman..."
    dryrun sudo pacman -S --needed --noconfirm mise
fi

# ── Register and install plugins ─────────────────────────────────────────────

register_and_install() {
    local name="$1"
    local plugin_path="${PLUGINS_DIR}/${name}"

    if [[ ! -d "$plugin_path" ]]; then
        warn "Plugin directory not found: ${plugin_path}"
        return 1
    fi

    log "Registering local ${name} plugin..."
    dryrun mise plugins install "$name" "$plugin_path"

    log "Installing latest ${name} via mise..."
    dryrun mise install "${name}@latest"
}

register_and_install ollama
register_and_install claude-code
register_and_install droid-factory

# ── WSL browser auth hint ────────────────────────────────────────────────────

if grep -qi microsoft /proc/version 2>/dev/null; then
    info "WSL detected — ensure xdg-utils and wslu are installed for browser auth"
fi

log "Mise plugin infrastructure complete."
