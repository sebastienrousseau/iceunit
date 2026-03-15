#!/usr/bin/env bash
# =============================================================================
# 04-bootloader.sh
# Bootloader Management for MacBook Air 2020 (MacBookAir9,1) on CachyOS
#
# Your confirmed setup:
#   Bootloader:  Limine 10.8.2
#   ESP:         /dev/nvme0n1p1 (FAT32, 3.9G, mounted at /boot)
#   Boot order:  Limine → Mac OS X → Zorin OS (EFI variables)
#   Snapshots:   8 BTRFS snapshots via limine-snapper-sync ✓
#   rEFInd:      NOT installed
#
# This script helps you:
#   1. Understand and manage your Limine configuration
#   2. Optionally add rEFInd as a graphical boot picker
#   3. Safely update kernel cmdline parameters
#   4. Manage boot order between macOS / CachyOS / other OSes
# =============================================================================

set -euo pipefail

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

require_root() {
    [[ $EUID -eq 0 ]] || error "Run with sudo: sudo bash $0"
}

ESP="/boot"
LIMINE_CONF="${ESP}/limine.conf"

# ── Show current boot status ──────────────────────────────────────────────────
show_status() {
    header "Current Boot Configuration"

    info "Bootloader: Limine 10.8.2"
    info "ESP: ${ESP} (nvme0n1p1)"

    echo ""
    info "EFI boot order:"
    efibootmgr 2>/dev/null | grep -E "^Boot[0-9]" | while read -r line; do
        echo "  ${line}"
    done || warn "efibootmgr not available"

    echo ""
    info "Running kernel:"
    uname -r

    echo ""
    info "BTRFS snapshots in boot menu:"
    grep "comment: [0-9]" "${LIMINE_CONF}" 2>/dev/null | head -10 \
        | sed 's/.*comment: /  /' || warn "Cannot read limine.conf (need sudo)"

    echo ""
    info "Current kernel cmdline:"
    cat /proc/cmdline
}

# ── Update kernel parameters ──────────────────────────────────────────────────
update_cmdline() {
    header "Updating Kernel Cmdline"

    # Limine on CachyOS uses limine-entry-tool which reads from:
    #   /etc/kernel/cmdline
    # and regenerates /boot/limine.conf entries automatically on kernel updates.
    # Do NOT manually edit /boot/limine.conf for cmdline changes.

    local cmdline_file="/etc/kernel/cmdline"

    info "Current /etc/kernel/cmdline:"
    cat "$cmdline_file" 2>/dev/null || echo "  (file not found — using kernel defaults)"

    echo ""
    echo "Recommended cmdline for MacBook Air 2020:"
    echo ""
    echo "  quiet nowatchdog splash rw \\"
    echo "    intel_idle.max_cstate=4 \\"
    echo "    snd_hda_intel.power_save=0 \\"
    echo "    pcie_aspm=off \\"
    echo "    mem_sleep_default=deep \\"
    echo "    rootflags=subvol=/@ \\"
    echo "    root=UUID=$(findmnt -rno UUID /)"
    echo ""

    read -rp "Write recommended cmdline to ${cmdline_file}? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        # Back up current
        cp "$cmdline_file" "${cmdline_file}.bak" 2>/dev/null || true

        cat > "$cmdline_file" << 'EOF'
quiet nowatchdog splash rw intel_idle.max_cstate=4 snd_hda_intel.power_save=0 pcie_aspm=off mem_sleep_default=deep
EOF
        success "cmdline updated (root= and rootflags= are added by limine-entry-tool automatically)"

        info "Regenerating Limine entries..."
        if command -v limine-entry-tool &>/dev/null; then
            limine-entry-tool
            success "Limine entries regenerated"
        else
            warn "limine-entry-tool not found in PATH — entries will update on next kernel install"
        fi
    else
        info "Skipped — no changes made"
    fi
}

# ── Install rEFInd (optional graphical picker) ─────────────────────────────────
install_refind() {
    header "Installing rEFInd (Optional Graphical Boot Picker)"

    cat << 'INFO'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 rEFInd vs Limine — which should you use?
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 Your current setup (Limine) is BETTER for:
   ✓ BTRFS snapshot booting (limine-snapper-sync is excellent)
   ✓ Automatic kernel updates without manual config
   ✓ CachyOS-native integration
   ✓ Fast boot times

 rEFInd is better for:
   ✓ Graphical boot menu with mouse support
   ✓ Auto-detecting macOS and Linux side-by-side beautifully
   ✓ Users who frequently switch between macOS and CachyOS
   ✓ The classic "Mac boot picker" feel

 RECOMMENDATION: Keep Limine as primary bootloader.
 Install rEFInd as a secondary boot option selectable from
 the EFI boot menu (Option key at startup), not as primary.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
INFO

    read -rp "Install rEFInd as secondary EFI option? [y/N] " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { info "rEFInd installation skipped"; return; }

    require_root

    # Install rEFInd
    if ! pacman -Q refind &>/dev/null; then
        info "Installing refind..."
        pacman -S --noconfirm refind || error "Failed to install refind"
    else
        success "refind already installed"
    fi

    # Install to ESP WITHOUT making it the default boot entry
    info "Installing rEFInd to ESP (not setting as default boot)..."
    refind-install --usedefault /dev/nvme0n1p1 --no-confirm \
        || refind-install --no-confirm \
        || error "refind-install failed — see output above"

    # Configure rEFInd for MacBook Air 2020
    local refind_conf="${ESP}/EFI/refind/refind.conf"
    if [[ -f "$refind_conf" ]]; then
        cat >> "$refind_conf" << 'EOF'

# ── MacBook Air 2020 (MacBookAir9,1) tweaks ──
# Scan for Linux and macOS, skip Windows
scanfor internal,external,optical,manual
scan_driver_dirs EFI/tools

# Timeout — 5 seconds before auto-boot
timeout 5

# Use default_selection to prefer CachyOS
# default_selection "+,vmlinuz"

# Enable mouse for trackpad support
enable_mouse true
mouse_speed 8

# Screen resolution
resolution max

# Hide duplicate entries from Limine
dont_scan_files shimx64.efi,fbx64.efi

EOF
        success "rEFInd configured for MacBook Air 2020"
    fi

    # Set boot order: Limine first, rEFInd second
    info "Setting EFI boot order: Limine → rEFInd → macOS..."
    local limine_id
    limine_id=$(efibootmgr | grep -i "limine" | grep -oP 'Boot\K[0-9A-F]+' | head -1)
    local refind_id
    refind_id=$(efibootmgr | grep -i "refind" | grep -oP 'Boot\K[0-9A-F]+' | head -1)

    local macos_id
    macos_id=$(efibootmgr | grep -i "mac" | grep -oP 'Boot\K[0-9A-Fa-f]+' | head -1)

    if [[ -n "$limine_id" ]] && [[ -n "$refind_id" ]]; then
        local boot_order="${limine_id},${refind_id}"
        [[ -n "$macos_id" ]] && boot_order="${boot_order},${macos_id}"
        if efibootmgr -o "$boot_order" 2>/dev/null; then
            success "Boot order updated: Limine → rEFInd → macOS"
        else
            warn "Could not set boot order — set manually with efibootmgr"
        fi
    fi

    echo ""
    success "rEFInd installed!"
    info "To boot with rEFInd: hold Option (⌥) at startup and select rEFInd"
    info "Or: sudo efibootmgr -n $(efibootmgr | grep -i refind | grep -oP 'Boot\K[0-9A-F]+' | head -1)"
}

# ── Manage boot order ─────────────────────────────────────────────────────────
manage_boot_order() {
    header "EFI Boot Order Management"

    info "Current boot entries:"
    efibootmgr 2>/dev/null || error "efibootmgr not available"

    # Detect boot entry IDs dynamically
    local limine_boot_id macos_boot_id
    limine_boot_id=$(efibootmgr | grep -i "limine" | grep -oP 'Boot\K[0-9A-Fa-f]+' | head -1)
    macos_boot_id=$(efibootmgr | grep -i "mac" | grep -oP 'Boot\K[0-9A-Fa-f]+' | head -1)

    echo ""
    echo "Detected entries:"
    [[ -n "$limine_boot_id" ]] && echo "  0x${limine_boot_id} — Limine (CachyOS)" || echo "  Limine entry not found"
    [[ -n "$macos_boot_id" ]] && echo "  0x${macos_boot_id} — Mac OS X" || echo "  macOS entry not found"
    echo ""
    echo "Options:"
    echo "  1) Boot into macOS once (next boot only)"
    echo "  2) Boot into CachyOS next"
    echo "  3) Set permanent boot order"
    echo "  4) Show all EFI entries"
    echo "  b) Back"
    echo ""
    read -rp "Choice: " choice

    case "$choice" in
        1)
            [[ -n "$macos_boot_id" ]] || error "macOS boot entry not found in efibootmgr output"
            efibootmgr -n "$macos_boot_id"
            success "Next boot: macOS (will revert to default after that)"
            ;;
        2)
            [[ -n "$limine_boot_id" ]] || error "Limine boot entry not found in efibootmgr output"
            efibootmgr -n "$limine_boot_id"
            success "Next boot: CachyOS via Limine"
            ;;
        3)
            read -rp "Boot order (comma-separated IDs, e.g. 0001,0080): " order
            if [[ ! "$order" =~ ^[0-9A-Fa-f]+(,[0-9A-Fa-f]+)*$ ]]; then
                error "Invalid boot order format. Use comma-separated hex IDs (e.g. 0001,0080)"
            fi
            efibootmgr -o "$order"
            success "Boot order set"
            ;;
        4)
            efibootmgr -v
            ;;
        b|B) return ;;
        *) warn "Invalid choice" ;;
    esac
}

# ── BTRFS snapshot boot guide ─────────────────────────────────────────────────
show_snapshot_guide() {
    header "BTRFS Snapshot Boot Guide"

    cat << 'GUIDE'
Your Limine setup with limine-snapper-sync is excellent.
Snapshots available in the boot menu are listed below.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 How to boot from a snapshot:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 1. Hold Space at boot when the Limine splash appears
 2. Select "CachyOS" → "Snapshots"
 3. Choose the snapshot by date/description
    (e.g., "262 │ 2026-03-07 12:39:34 — topgrade")

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 How to rollback to a snapshot permanently:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 After booting into the snapshot you want:

  # Option A — via snapper
  sudo snapper rollback <snapshot_number>
  sudo reboot

  # Option B — manual BTRFS rollback
  sudo btrfs subvolume delete /@
  sudo btrfs subvolume snapshot /.snapshots/<N>/snapshot /@
  sudo reboot

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Current snapshots:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GUIDE

    snapper list 2>/dev/null || warn "snapper not available — install with: sudo pacman -S snapper"
}

# ── Interactive menu ──────────────────────────────────────────────────────────
interactive() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  MacBook Air 2020 — Bootloader Management           ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo "1) Show current boot status"
    echo "2) Update kernel cmdline parameters"
    echo "3) Install rEFInd (optional graphical picker)"
    echo "4) Manage EFI boot order"
    echo "5) BTRFS snapshot boot guide"
    echo "q) Quit"
    echo ""
    read -rp "Choice: " choice
    case "$choice" in
        1) show_status ;;
        2) require_root; update_cmdline ;;
        3) require_root; install_refind ;;
        4) require_root; manage_boot_order ;;
        5) show_snapshot_guide ;;
        q) exit 0 ;;
        *) error "Invalid choice" ;;
    esac
}

if [[ "${1:-}" == "--yes" ]] || [[ "$ASSUME_YES" == "true" ]]; then
    # In non-interactive mode, we default to status check
    show_status
    exit 0
fi

case "${1:-}" in
    status)    show_status ;;
    cmdline)   require_root; update_cmdline ;;
    refind)    require_root; install_refind ;;
    bootorder) require_root; manage_boot_order ;;
    snapshots) show_snapshot_guide ;;
    --help|-h) echo "Usage: $0 [status|cmdline|refind|bootorder|snapshots]" ;;
    "")        interactive ;;
    *)         echo "Usage: $0 [status|cmdline|refind|bootorder|snapshots]"; exit 1 ;;
esac
