#!/usr/bin/env bash
# =============================================================================
# 06-unmount-vault.sh
# Unmount and lock the LUKS2 encrypted code vault
#
# Unmounts ~/Code and closes the cryptsetup container.
# Safe to run if already unmounted (exits cleanly).
#
# Usage:
#   bash scripts/06-unmount-vault.sh [--dry-run] [--help]
# =============================================================================

set -euo pipefail

DRY_RUN=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help|-h)
            echo "Usage: bash $0 [--dry-run] [--help]"
            echo "Unmount and lock the LUKS2 encrypted code vault."
            exit 0
            ;;
    esac
done

# Wrapper for destructive commands
dryrun() {
    if $DRY_RUN; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

MAPPER_NAME="code_vault"
MOUNT_POINT="$HOME/Code"

info "Securing and unmounting the code vault..."

# Unmount if mounted
if findmnt -rno TARGET "$MOUNT_POINT" &>/dev/null; then
    info "Unmounting ${MOUNT_POINT}..."
    dryrun sudo umount "$MOUNT_POINT" || error "Failed to unmount ${MOUNT_POINT} — a process may be using it"
else
    info "Vault is not currently mounted."
fi

# Close LUKS container if open
if [[ -e "/dev/mapper/$MAPPER_NAME" ]]; then
    info "Closing encrypted container..."
    dryrun sudo cryptsetup close "$MAPPER_NAME"
    success "Vault locked and secured."
else
    success "Vault is already locked."
fi
