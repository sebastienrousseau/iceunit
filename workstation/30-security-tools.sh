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

log "=== Security Tooling Setup ==="

dryrun sudo pacman -Sy --needed --noconfirm gitleaks age sops openssh gnupg ufw

# Enable firewall
dryrun sudo systemctl enable --now ufw || true
dryrun sudo ufw default deny incoming || true
dryrun sudo ufw default allow outgoing || true

log "Security tooling configured."
