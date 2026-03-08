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

log "=== DevOps Tooling Setup ==="

dryrun sudo pacman -Sy --needed --noconfirm kubectl helm k9s terraform ansible stern dive rsync

# Install kubectl completion
if command -v kubectl >/dev/null 2>&1; then
  dryrun kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl >/dev/null || true
fi

log "DevOps tooling installed."
