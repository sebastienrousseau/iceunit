#!/usr/bin/env bash
# =============================================================================
# 05-desktop-base.sh
# Desktop Foundation for MacBook Air 2020 (MacBookAir9,1) on CachyOS
#
# Problem: The core hardware scripts (00–08) assume a working GNOME
#          desktop, but never install the desktop environment itself,
#          display manager, fonts, firmware updater, CPU microcode,
#          or essential timers (fstrim, paccache).
#
# This script bridges that gap — ensuring the desktop foundation is
# fully installed and enabled before workstation modules run.
#
# Hardware confirmed:
#   Model:   MacBook Air 2020 (MacBookAir9,1) — NO Touch Bar
#   CPU:     Intel Core i5-1030NG7 (Ice Lake) — intel-ucode required
#   Kernel:  6.19.x-cachyos  |  Driver: apple_bce (T2 bridge)
#   Boot:    Limine (not GRUB)
# =============================================================================

set -Eeuo pipefail

DRY_RUN=false
for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
    [[ "$arg" == "--help" || "$arg" == "-h" ]] && {
        echo "Usage: sudo bash $0 [--dry-run] [--help]"
        echo "Install and enable desktop foundation packages and services."
        exit 0
    }
done

# Wrapper for destructive commands
dryrun() {
    if $DRY_RUN; then
        echo "[DRY-RUN] $*"
    else
        "$@"
    fi
}

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }
header()  { echo -e "\n${BOLD}${CYAN}== $* ==${RESET}\n"; }
skip()    { echo -e "  ${YELLOW}-> skipped${RESET}  $*"; }

APPLIED=()
SKIPPED=()

mark_applied() { APPLIED+=("$1"); }
mark_skipped() { SKIPPED+=("$1"); }

require_root() {
    $DRY_RUN && return 0
    [[ $EUID -eq 0 ]] || error "Run with sudo: sudo bash $0"
}

# ── 1. Desktop Environment ───────────────────────────────────────────────────
install_desktop() {
    header "Desktop Environment"

    local de_pkgs=(gnome gdm)
    local missing=()

    for pkg in "${de_pkgs[@]}"; do
        if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        success "GNOME and GDM already installed"
        mark_skipped "desktop-environment"
        return
    fi

    info "Installing desktop environment: ${missing[*]}"
    dryrun pacman -S --needed --noconfirm "${missing[@]}"
    success "Desktop environment installed"
    mark_applied "desktop-environment"
}

# ── 2. NetworkManager ────────────────────────────────────────────────────────
setup_networkmanager() {
    header "NetworkManager"

    if ! pacman -Qq networkmanager >/dev/null 2>&1; then
        info "Installing NetworkManager..."
        dryrun pacman -S --needed --noconfirm networkmanager
        mark_applied "networkmanager-install"
    else
        success "NetworkManager already installed"
    fi

    if systemctl is-enabled NetworkManager >/dev/null 2>&1; then
        success "NetworkManager already enabled"
        mark_skipped "networkmanager-enable"
    else
        info "Enabling NetworkManager..."
        dryrun systemctl enable --now NetworkManager
        success "NetworkManager enabled"
        mark_applied "networkmanager-enable"
    fi
}

# ── 3. Audio Stack (PipeWire) ────────────────────────────────────────────────
setup_audio() {
    header "Audio Stack (PipeWire)"

    local audio_pkgs=(pipewire pipewire-pulse wireplumber)
    local missing=()

    for pkg in "${audio_pkgs[@]}"; do
        if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        success "PipeWire audio stack already installed"
        mark_skipped "pipewire"
        return
    fi

    info "Installing PipeWire audio stack: ${missing[*]}"
    dryrun pacman -S --needed --noconfirm "${missing[@]}"
    success "PipeWire installed"
    mark_applied "pipewire"
}

# ── 4. XDG User Directories ─────────────────────────────────────────────────
setup_xdg_dirs() {
    header "XDG User Directories"

    if ! pacman -Qq xdg-user-dirs >/dev/null 2>&1; then
        info "Installing xdg-user-dirs..."
        dryrun pacman -S --needed --noconfirm xdg-user-dirs
        mark_applied "xdg-user-dirs"
    else
        success "xdg-user-dirs already installed"
    fi

    # Create standard user directories
    if [[ -n "${SUDO_USER:-}" ]]; then
        info "Initialising XDG directories for ${SUDO_USER}..."
        dryrun sudo -u "$SUDO_USER" xdg-user-dirs-update
        mark_applied "xdg-dirs-init"
    fi
}

# ── 5. Fonts ─────────────────────────────────────────────────────────────────
install_fonts() {
    header "Fonts"

    local font_pkgs=(noto-fonts noto-fonts-emoji ttf-dejavu ttf-liberation)
    local missing=()

    for pkg in "${font_pkgs[@]}"; do
        if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
            missing+=("$pkg")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        success "All font packages already installed"
        mark_skipped "fonts"
        return
    fi

    info "Installing fonts: ${missing[*]}"
    dryrun pacman -S --needed --noconfirm "${missing[@]}"
    success "Fonts installed"
    mark_applied "fonts"
}

# ── 6. Firmware Update Daemon ────────────────────────────────────────────────
setup_fwupd() {
    header "Firmware Updates (fwupd)"

    if ! pacman -Qq fwupd >/dev/null 2>&1; then
        info "Installing fwupd..."
        dryrun pacman -S --needed --noconfirm fwupd
        mark_applied "fwupd-install"
    else
        success "fwupd already installed"
    fi

    if systemctl is-enabled fwupd.service >/dev/null 2>&1; then
        success "fwupd.service already enabled"
        mark_skipped "fwupd-enable"
    else
        info "Enabling fwupd.service..."
        dryrun systemctl enable --now fwupd.service
        success "fwupd.service enabled"
        mark_applied "fwupd-enable"
    fi
}

# ── 7. CPU Microcode ─────────────────────────────────────────────────────────
install_microcode() {
    header "CPU Microcode"

    if pacman -Qq intel-ucode >/dev/null 2>&1; then
        success "intel-ucode already installed"
        mark_skipped "microcode"
        return
    fi

    info "Installing Intel CPU microcode..."
    dryrun pacman -S --needed --noconfirm intel-ucode
    success "intel-ucode installed"
    warn "Regenerate boot entries for microcode to take effect"
    mark_applied "microcode"
}

# ── 8. Maintenance Utilities ─────────────────────────────────────────────────
setup_maintenance_utils() {
    header "Maintenance Utilities"

    if ! pacman -Qq pacman-contrib >/dev/null 2>&1; then
        info "Installing pacman-contrib (paccache, checkupdates)..."
        dryrun pacman -S --needed --noconfirm pacman-contrib
        mark_applied "pacman-contrib"
    else
        success "pacman-contrib already installed"
    fi
}

# ── 9. System Timers ─────────────────────────────────────────────────────────
enable_timers() {
    header "System Timers"

    # fstrim.timer — periodic SSD TRIM
    if systemctl is-enabled fstrim.timer >/dev/null 2>&1; then
        success "fstrim.timer already enabled"
        mark_skipped "fstrim-timer"
    else
        info "Enabling fstrim.timer for periodic SSD TRIM..."
        dryrun systemctl enable --now fstrim.timer
        success "fstrim.timer enabled"
        mark_applied "fstrim-timer"
    fi

    # paccache.timer — weekly package cache cleanup
    if systemctl is-enabled paccache.timer >/dev/null 2>&1; then
        success "paccache.timer already enabled"
        mark_skipped "paccache-timer"
    else
        if systemctl list-unit-files | grep -q "^paccache.timer"; then
            info "Enabling paccache.timer for weekly cache cleanup..."
            dryrun systemctl enable --now paccache.timer
            success "paccache.timer enabled"
            mark_applied "paccache-timer"
        else
            skip "paccache.timer unit not found (install pacman-contrib)"
            mark_skipped "paccache-timer"
        fi
    fi
}

# ── 10. Bluetooth Service ────────────────────────────────────────────────────
enable_bluetooth() {
    header "Bluetooth Service"

    if ! pacman -Qq bluez >/dev/null 2>&1 || ! pacman -Qq bluez-utils >/dev/null 2>&1; then
        info "Installing bluez and bluez-utils..."
        dryrun pacman -S --needed --noconfirm bluez bluez-utils
        mark_applied "bluetooth-install"
    else
        success "bluez already installed"
    fi

    if systemctl is-enabled bluetooth >/dev/null 2>&1; then
        success "bluetooth.service already enabled"
        mark_skipped "bluetooth-enable"
    else
        info "Enabling bluetooth.service..."
        dryrun systemctl enable --now bluetooth
        success "bluetooth.service enabled"
        mark_applied "bluetooth-enable"
    fi
}

# ── 11. GDM Enablement ───────────────────────────────────────────────────────
enable_gdm() {
    header "Display Manager"

    if ! pacman -Qq gdm >/dev/null 2>&1; then
        skip "GDM not installed — install desktop environment first"
        mark_skipped "gdm-enable"
        return
    fi

    if systemctl is-enabled gdm >/dev/null 2>&1; then
        success "GDM already enabled"
        mark_skipped "gdm-enable"
    else
        info "Enabling GDM..."
        dryrun systemctl enable gdm
        success "GDM enabled (will start on next reboot)"
        mark_applied "gdm-enable"
    fi
}

# ── Summary ──────────────────────────────────────────────────────────────────
print_summary() {
    header "Desktop Base Summary"

    if [[ ${#APPLIED[@]} -gt 0 ]]; then
        info "Applied:"
        for item in "${APPLIED[@]}"; do
            echo -e "  ${GREEN}+${RESET} $item"
        done
    fi

    if [[ ${#SKIPPED[@]} -gt 0 ]]; then
        info "Already configured:"
        for item in "${SKIPPED[@]}"; do
            echo -e "  ${CYAN}-${RESET} $item"
        done
    fi

    echo ""
    success "Desktop base setup complete"
}

# ── Entry point ──────────────────────────────────────────────────────────────
case "${1:-}" in
    --dry-run|--help|-h|"")
        require_root
        install_desktop
        setup_networkmanager
        setup_audio
        setup_xdg_dirs
        install_fonts
        setup_fwupd
        install_microcode
        setup_maintenance_utils
        enable_timers
        enable_bluetooth
        enable_gdm
        print_summary
        ;;
    *)
        echo "Usage: sudo bash $0 [--dry-run] [--help]"
        exit 1
        ;;
esac
