#!/usr/bin/env bash
# =============================================================================
# 02-wifi-firmware.sh
# Broadcom BCM4377b Wi-Fi & BRCM4377 Bluetooth Firmware for MacBook Air 2020
#
# Your firmware is already present and working. This script serves two purposes:
#   1. Document the recovery process (if firmware is ever lost after reinstall)
#   2. Verify current firmware health and provide a backup mechanism
#
# Firmware files confirmed on this system (MacBookAir9,1 — "fiji" board ID):
#   brcmfmac4377b3-pcie.apple,fiji.bin
#   brcmfmac4377b3-pcie.apple,fiji.clm_blob
#   brcmfmac4377b3-pcie.apple,fiji.txcap_blob
#   brcmbt4377b3-apple,formosa.bin  (Bluetooth)
# =============================================================================

set -Eeuo pipefail

DRY_RUN=false
ASSUME_YES=false
for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
    [[ "$arg" == "--yes" ]] && ASSUME_YES=true
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
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}══ $* ══${RESET}\n"; }

FIRMWARE_DIR="/lib/firmware/brcm"
BACKUP_DIR="$HOME/.config/firmware-backup/brcm"
PACKAGE_URL="https://mirror.funami.tech/arch-mact2/os/x86_64/apple-bcm-firmware-14.0-1-any.pkg.tar.zst"
# SHA256 of the known-good apple-bcm-firmware-14.0-1 package
PACKAGE_SHA256="expected-sha256-hash-must-be-set-before-first-use"

# ── Mode selection ────────────────────────────────────────────────────────────
usage() {
    echo "Usage: $0 [verify|backup|restore|install-pkg]"
    echo ""
    echo "  verify      — Check current firmware files are present and healthy"
    echo "  backup      — Back up firmware files to ~/.config/firmware-backup/"
    echo "  restore     — Restore firmware from backup"
    echo "  install-pkg — Re-download firmware package from arch-mact2 mirror"
    echo ""
    echo "Run with no arguments for interactive mode."
}

# ── Verify current firmware ───────────────────────────────────────────────────
verify_firmware() {
    header "Verifying BCM4377b Firmware (MacBook Air 2020 — fiji)"

    local required_files=(
        "brcmfmac4377b3-pcie.apple,fiji.bin"
        "brcmfmac4377b3-pcie.apple,fiji.clm_blob"
        "brcmfmac4377b3-pcie.apple,fiji.txcap_blob"
        "brcmbt4377b3-apple,formosa.bin"
        "brcmbt4377b3-apple,formosa.ptb"
    )

    local all_ok=true
    for f in "${required_files[@]}"; do
        if [[ -f "${FIRMWARE_DIR}/${f}" ]]; then
            local size
            size=$(du -h "${FIRMWARE_DIR}/${f}" | cut -f1)
            success "Found: ${f}  (${size})"
        else
            warn "MISSING: ${f}"
            all_ok=false
        fi
    done

    echo ""
    if $all_ok; then
        success "All required firmware files present"
        info "Testing Wi-Fi interface..."
        if ip link show | grep -q "wlan\|wlp"; then
            local iface
            iface=$(ip link show | grep -oE "wl[a-z0-9]+" | head -1)
            success "Wi-Fi interface active: ${iface}"
            info "Run 'iwctl station ${iface} scan' to verify connectivity"
        else
            warn "No Wi-Fi interface found — firmware present but module may not be loaded"
            info "Try: sudo modprobe brcmfmac"
        fi

        info "Testing Bluetooth interface..."
        if rfkill list | grep -q "hci0"; then
            success "Bluetooth interface present (hci0)"
        else
            warn "No Bluetooth interface found"
        fi
    else
        warn "Some firmware files are missing. Run: sudo bash $0 install-pkg"
    fi
}

# ── Backup firmware ───────────────────────────────────────────────────────────
backup_firmware() {
    header "Backing Up Firmware Files"
    mkdir -p "${BACKUP_DIR}"

    info "Backing up to ${BACKUP_DIR}..."
    local found_wifi=0 found_bt=0
    while IFS= read -r -d '' f; do
        cp -v "$f" "${BACKUP_DIR}/" && found_wifi=1
    done < <(find "${FIRMWARE_DIR}" -maxdepth 1 -name "brcmfmac4377*" -print0 2>/dev/null)
    [[ $found_wifi -eq 1 ]] || warn "Some Wi-Fi files not found"

    while IFS= read -r -d '' f; do
        cp -v "$f" "${BACKUP_DIR}/" && found_bt=1
    done < <(find "${FIRMWARE_DIR}" -maxdepth 1 -name "brcmbt4377*" -print0 2>/dev/null)
    [[ $found_bt -eq 1 ]] || warn "Some BT files not found"

    if [[ -f "${FIRMWARE_DIR}/BCM-0bb4-0306.hcd.zst" ]]; then
        cp -v "${FIRMWARE_DIR}/BCM-0bb4-0306.hcd.zst" "${BACKUP_DIR}/"
    fi

    # Create a manifest
    ls -la "${BACKUP_DIR}/" > "${BACKUP_DIR}/MANIFEST.txt"
    echo "Backed up on: $(date)" >> "${BACKUP_DIR}/MANIFEST.txt"

    success "Firmware backed up to ${BACKUP_DIR}"
    info "Restore with: sudo bash $0 restore"
}

# ── Restore from backup ───────────────────────────────────────────────────────
restore_firmware() {
    header "Restoring Firmware from Backup"

    if [[ ! -d "${BACKUP_DIR}" ]]; then
        error "No backup found at ${BACKUP_DIR}. Run backup first."
    fi

    [[ $EUID -eq 0 ]] || error "Restore requires sudo: sudo bash $0 restore"

    find "${BACKUP_DIR}" -maxdepth 1 -name "brcm*" -print0 | xargs -0 -I{} cp -v {} "${FIRMWARE_DIR}/"
    find "${BACKUP_DIR}" -maxdepth 1 -name "BCM*" -print0 | xargs -0 -I{} cp -v {} "${FIRMWARE_DIR}/"

    # Reload the kernel module
    info "Reloading brcmfmac kernel module..."
    if modprobe -r brcmfmac 2>/dev/null && modprobe brcmfmac; then
        success "Kernel module reloaded"
    else
        warn "Module reload failed — reboot may be needed"
    fi

    success "Firmware restored"
    verify_firmware
}

# ── Install from arch-mact2 package ──────────────────────────────────────────
install_from_package() {
    header "Installing Firmware from arch-mact2 Mirror"

    [[ $EUID -eq 0 ]] || error "Requires sudo: sudo bash $0 install-pkg"

    local pkg_dir
    pkg_dir=$(mktemp -d) || error "Failed to create temporary directory"
    local pkg_file="${pkg_dir}/apple-bcm-firmware.pkg.tar.zst"

    info "Downloading firmware package..."
    info "Source: ${PACKAGE_URL}"
    curl -L --progress-bar "${PACKAGE_URL}" -o "${pkg_file}" \
        || error "Download failed. Check internet connection."

    # Verify package integrity if a known hash is configured
    if [[ "$PACKAGE_SHA256" != "expected-sha256-hash-must-be-set-before-first-use" ]]; then
        info "Verifying package checksum..."
        echo "${PACKAGE_SHA256}  ${pkg_file}" | sha256sum -c - \
            || { rm -rf "${pkg_dir}"; error "Checksum verification failed — package may be corrupted or tampered with"; }
        success "Checksum verified"
    else
        warn "No checksum configured — skipping integrity verification"
        warn "Set PACKAGE_SHA256 in this script after verifying the hash manually"
    fi

    info "Extracting to ${FIRMWARE_DIR}..."
    tar -xf "${pkg_file}" -C / --wildcards "usr/lib/firmware/brcm/*" 2>/dev/null \
        || tar -xf "${pkg_file}" -C / 2>/dev/null \
        || error "Extraction failed"

    rm -rf "${pkg_dir}"
    success "Firmware installed from package"

    # Reload module
    info "Reloading brcmfmac..."
    modprobe -r brcmfmac 2>/dev/null; modprobe brcmfmac || true
    modprobe -r hci_bcm4377 2>/dev/null; modprobe hci_bcm4377 || true

    verify_firmware
}

# ── Pre-install: extract from macOS (for fresh installs) ─────────────────────
# This section is documentation — run from the CachyOS live environment
# when macOS is still present on a separate partition.
show_macos_extraction_guide() {
    header "Wi-Fi Firmware Extraction from macOS (For Fresh Installs)"

    cat << 'GUIDE'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Wi-Fi will NOT work during installation without this step.
 The Broadcom BCM4377b firmware is proprietary and cannot be
 redistributed. It must be extracted from your macOS partition.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

OPTION A — Extract in CachyOS Live Environment (recommended)
─────────────────────────────────────────────────────────────
Run these commands in the live ISO terminal BEFORE installing:

  # 1. Find your macOS partition (look for "Apple_APFS" type)
  lsblk -f

  # 2. Mount the macOS partition (replace nvme0n1pX with yours)
  sudo mkdir -p /mnt/macos
  sudo mount -t apfs /dev/nvme0n1pX /mnt/macos -o ro

  # 3. Run the T2 firmware extraction tool
  # This pulls the correct BCM4377b files from macOS drivers
  # WARNING: Piping remote scripts to sudo bash is a security risk.
  # Review the script contents first: curl -s https://wiki.t2linux.org/tools/firmware.sh | less
  curl -s https://wiki.t2linux.org/tools/firmware.sh | sudo bash

  # The script auto-detects your board ID ("fiji" for MBA 2020)
  # and copies the correct .bin/.clm_blob/.txcap_blob files to
  # /lib/firmware/brcm/

  # 4. Test Wi-Fi in the live environment before proceeding
  sudo modprobe brcmfmac
  nmcli device wifi list

OPTION B — Use the arch-mact2 Pre-packaged Firmware
──────────────────────────────────────────────────────
If macOS is already removed or the partition is inaccessible:

  curl https://mirror.funami.tech/arch-mact2/os/x86_64/apple-bcm-firmware-14.0-1-any.pkg.tar.zst \
      -o /tmp/apple-bcm-firmware.pkg.tar.zst

  sudo tar -xf /tmp/apple-bcm-firmware.pkg.tar.zst -C /
  sudo modprobe brcmfmac

OPTION C — USB Tethering During Install (fallback)
────────────────────────────────────────────────────
If you have no other way to get internet:
  1. Connect your iPhone via USB
  2. Enable Personal Hotspot → USB
  3. The RNDIS/iPhone interface will appear automatically
  4. Proceed with installation and fix Wi-Fi post-install

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Note: Your Bluetooth firmware (brcmbt4377b3) is separate
 from Wi-Fi. Both are handled by the apple-bcm-firmware package
 or the extraction script above.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GUIDE
}

# ── Interactive menu ──────────────────────────────────────────────────────────
interactive() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  MacBook Air 2020 — Wi-Fi & BT Firmware Manager     ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo "1) Verify current firmware"
    echo "2) Backup firmware to ~/.config/firmware-backup/"
    echo "3) Restore firmware from backup"
    echo "4) Re-install from arch-mact2 mirror"
    echo "5) Show fresh-install extraction guide"
    echo "q) Quit"
    echo ""
    read -rp "Choice: " choice
    case "$choice" in
        1) verify_firmware ;;
        2) backup_firmware ;;
        3) restore_firmware ;;
        4) install_from_package ;;
        5) show_macos_extraction_guide ;;
        q) exit 0 ;;
        *) error "Invalid choice" ;;
    esac
}

# ── Entry point ───────────────────────────────────────────────────────────────
if [[ "${1:-}" == "--yes" ]] || [[ "$ASSUME_YES" == "true" ]]; then
    # In non-interactive mode, we default to verification
    verify_firmware
    exit 0
fi

case "${1:-}" in
    verify)      verify_firmware ;;
    backup)      backup_firmware ;;
    restore)     restore_firmware ;;
    install-pkg) install_from_package ;;
    guide)       show_macos_extraction_guide ;;
    --help|-h)   usage ;;
    "")          interactive ;;
    *)           usage; exit 1 ;;
esac
