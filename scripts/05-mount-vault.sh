#!/usr/bin/env bash
# =============================================================================
# 05-mount-vault.sh
# Unlock and mount the LUKS2 encrypted code vault
#
# Opens ~/.vault.img via cryptsetup and mounts it at ~/Code.
# Safe to run if already mounted (exits cleanly).
#
# Usage:
#   bash scripts/05-mount-vault.sh [--dry-run] [--help]
# =============================================================================

set -euo pipefail

DRY_RUN=false
ASSUME_YES=false
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --yes) ASSUME_YES=true ;;
        --help|-h)
            echo "Usage: bash $0 [--dry-run] [--help]"
            echo "Unlock and mount the LUKS2 encrypted code vault."
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

# Detect real user even if running with sudo
REAL_USER="${SUDO_USER:-${USER:-$(whoami)}}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

MAPPER_NAME="code_vault"
MOUNT_POINT="$REAL_HOME/Code"
VAULT_IMG="$REAL_HOME/.vault.img"

info "Unlocking and mounting the code vault for $REAL_USER..."

# Already mounted — nothing to do
if findmnt -rno TARGET "$MOUNT_POINT" &>/dev/null; then
    success "Vault is already mounted at ${MOUNT_POINT}"
    exit 0
fi

# Check vault image exists
[[ -f "$VAULT_IMG" ]] || error "Vault image not found at ${VAULT_IMG}. Run 00-setup-vault.sh first."

# Open LUKS container if not already open
if [[ ! -e "/dev/mapper/$MAPPER_NAME" ]]; then
    if [[ ! -t 0 ]] && [[ "$ASSUME_YES" == "true" ]]; then
        warn "Non-interactive mode: cannot prompt for LUKS passphrase. Skipping vault mount."
        exit 0
    fi
    dryrun sudo cryptsetup open "$VAULT_IMG" "$MAPPER_NAME"
fi

# Create mount point if needed and mount
mkdir -p "$MOUNT_POINT"
dryrun sudo mount "/dev/mapper/$MAPPER_NAME" "$MOUNT_POINT"
dryrun sudo chown "$REAL_USER:$REAL_USER" "$MOUNT_POINT"

success "Vault mounted at ${MOUNT_POINT}"
