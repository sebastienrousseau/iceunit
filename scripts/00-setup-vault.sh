#!/usr/bin/env bash
# =============================================================================
# 00-setup-vault.sh
# First-time setup of the LUKS2 encrypted code vault
#
# This script creates a LUKS2-encrypted BTRFS loopback container at
# ~/.vault.img and mounts it at ~/Code. Run this ONCE on a fresh install.
#
# After running this script, use:
#   bash 05-mount-vault.sh    — unlock and mount the vault
#   bash 06-unmount-vault.sh  — lock and unmount the vault
#
# Why a loopback vault instead of full-disk encryption?
#   Your root partition is unencrypted BTRFS. This vault gives you a
#   separately encrypted container just for source code and secrets,
#   which you unlock manually after login. It lives inside your home
#   directory so it's included in any home backup automatically.
# =============================================================================

set -euo pipefail

DRY_RUN=false
for arg in "$@"; do [[ "$arg" == "--dry-run" ]] && DRY_RUN=true; done

# Wrapper for destructive commands
dryrun() {
    if $DRY_RUN; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

MAPPER_NAME="code_vault"
MOUNT_POINT="$HOME/Code"
VAULT_IMG="$HOME/.vault.img"
DEFAULT_SIZE="60G"

# ── Preflight ─────────────────────────────────────────────────────────────────
preflight() {
    header "Preflight Checks"

    command -v cryptsetup &>/dev/null || error "cryptsetup not found. Install with: sudo pacman -S cryptsetup"
    command -v mkfs.btrfs &>/dev/null || error "btrfs-progs not found. Install with: sudo pacman -S btrfs-progs"

    if [[ -f "$VAULT_IMG" ]]; then
        error "Vault image already exists at ${VAULT_IMG}. If you want to recreate it, delete it first.\nTo just mount the existing vault: bash 05-mount-vault.sh"
    fi

    if findmnt -rno TARGET "$MOUNT_POINT" &>/dev/null; then
        error "${MOUNT_POINT} is already mounted. Run 06-unmount-vault.sh first."
    fi

    success "All checks passed"
}

# ── Choose vault size ─────────────────────────────────────────────────────────
choose_size() {
    header "Vault Size"

    info "Your available disk space:"
    df -h "$HOME" | tail -1 | awk '{print "  Available: "$4"  (total "$2")"}'
    echo ""
    info "The vault is a fixed-size file. You cannot easily grow it later,"
    info "so choose generously. 60G is a good starting point for code repos."
    echo ""
    read -rp "Vault size [default: ${DEFAULT_SIZE}]: " input_size
    VAULT_SIZE="${input_size:-$DEFAULT_SIZE}"

    # Validate format
    if ! echo "$VAULT_SIZE" | grep -qE '^[1-9][0-9]*[GgMm]$'; then
        error "Invalid size '${VAULT_SIZE}'. Use format like 60G or 100G."
    fi

    info "Vault will be created at: ${VAULT_IMG} (${VAULT_SIZE})"
    echo ""
    read -rp "Continue? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "Aborted."; exit 0; }
}

# ── Create the image file ─────────────────────────────────────────────────────
create_image() {
    header "Creating Vault Image"

    info "Allocating ${VAULT_SIZE} at ${VAULT_IMG}..."
    info "(This may take a moment for large sizes)"
    fallocate -l "$VAULT_SIZE" "$VAULT_IMG" \
        || dd if=/dev/zero of="$VAULT_IMG" bs=1M count=0 seek="$(echo "$VAULT_SIZE" | numfmt --from=iec)" 2>/dev/null \
        || error "Failed to create vault image. Check available disk space."

    chmod 600 "$VAULT_IMG"
    success "Image created: ${VAULT_IMG} (${VAULT_SIZE})"
}

# ── LUKS2 format ──────────────────────────────────────────────────────────────
format_luks() {
    header "Encrypting the Vault (LUKS2)"

    echo ""
    warn "You will now set a passphrase for the vault."
    warn "This passphrase encrypts ALL your code. Do not forget it."
    warn "There is no recovery option if you lose it."
    echo ""

    sudo cryptsetup luksFormat \
        --type luks2 \
        --cipher aes-xts-plain64 \
        --key-size 512 \
        --hash sha512 \
        --pbkdf argon2id \
        "$VAULT_IMG"

    success "LUKS2 encryption applied"
}

# ── Open, format BTRFS, mount ─────────────────────────────────────────────────
initialise_filesystem() {
    header "Initialising BTRFS Filesystem"

    info "Opening encrypted container..."
    sudo cryptsetup open "$VAULT_IMG" "$MAPPER_NAME"

    info "Formatting with BTRFS..."
    sudo mkfs.btrfs -L CODE_REPOS /dev/mapper/"$MAPPER_NAME"

    info "Creating mount point at ${MOUNT_POINT}..."
    mkdir -p "$MOUNT_POINT"

    info "Mounting vault..."
    sudo mount /dev/mapper/"$MAPPER_NAME" "$MOUNT_POINT"

    info "Taking ownership..."
    sudo chown -R "$USER:$USER" "$MOUNT_POINT"

    success "Vault mounted at ${MOUNT_POINT}"
}

# ── Verify ────────────────────────────────────────────────────────────────────
verify() {
    header "Verification"

    if findmnt -rno TARGET "$MOUNT_POINT" &>/dev/null; then
        success "Vault is mounted and ready"
        df -h "$MOUNT_POINT" | tail -1 | awk '{print "  Available: "$4" of "$2}'
    else
        error "Mount verification failed — check output above"
    fi

    info "LUKS2 container details:"
    sudo cryptsetup luksDump "$VAULT_IMG" | grep -E "Version|Cipher|Hash|Label" | sed 's/^/  /'
}

# ── Post-setup instructions ───────────────────────────────────────────────────
print_next_steps() {
    header "Setup Complete"

    success "Your encrypted code vault is ready at ${MOUNT_POINT}"
    echo ""
    echo -e "${BOLD}Daily usage:${RESET}"
    echo "  Unlock:  bash scripts/05-mount-vault.sh"
    echo "  Lock:    bash scripts/06-unmount-vault.sh"
    echo ""
    echo -e "${BOLD}The vault image lives at:${RESET}"
    echo "  ${VAULT_IMG}  (hidden file, included in home backups)"
    echo ""
    echo -e "${BOLD}Important:${RESET}"
    echo "  • The vault is NOT auto-mounted at login — unlock it manually"
    echo "  • Never add ${VAULT_IMG} to /etc/fstab (causes boot issues)"
    echo "  • Back up ${VAULT_IMG} regularly — if the file is corrupted, data is lost"
    echo "  • Your passphrase cannot be recovered. Store it in a password manager."
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  MacBook Air 2020 — Encrypted Code Vault Setup      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    preflight
    choose_size
    create_image
    format_luks
    initialise_filesystem
    verify
    print_next_steps
}

main "$@"
