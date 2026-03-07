#!/usr/bin/env bash
# =============================================================================
# 05-mount-vault.sh
# Unlock and mount the LUKS2 encrypted code vault
#
# Opens ~/.vault.img via cryptsetup and mounts it at ~/Code.
# Safe to run if already mounted (exits cleanly).
#
# Usage:
#   bash scripts/05-mount-vault.sh
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

MAPPER_NAME="code_vault"
MOUNT_POINT="$HOME/Code"
VAULT_IMG="$HOME/.vault.img"

info "Unlocking and mounting the code vault..."

# Already mounted — nothing to do
if findmnt -rno TARGET "$MOUNT_POINT" &>/dev/null; then
    success "Vault is already mounted at ${MOUNT_POINT}"
    exit 0
fi

# Check vault image exists
[[ -f "$VAULT_IMG" ]] || error "Vault image not found at ${VAULT_IMG}. Run 00-setup-vault.sh first."

# Open LUKS container if not already open
if [[ ! -e "/dev/mapper/$MAPPER_NAME" ]]; then
    sudo cryptsetup open "$VAULT_IMG" "$MAPPER_NAME"
fi

# Create mount point if needed and mount
mkdir -p "$MOUNT_POINT"
sudo mount "/dev/mapper/$MAPPER_NAME" "$MOUNT_POINT"
sudo chown "$USER:$USER" "$MOUNT_POINT"

success "Vault mounted at ${MOUNT_POINT}"
