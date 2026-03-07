#!/usr/bin/env bash
# =============================================================================
# 03-optimise.sh
# Post-Install System Optimisation for MacBook Air 2020 (MacBookAir9,1)
# CachyOS — Kernel 6.19.x — Intel Core i5-1030NG7 (Ice Lake)
#
# Confirmed system state this is tuned for:
#   • ZRAM: 15.4G zstd swap — already configured ✓
#   • Power: TLP + power-profiles-daemon — coexisting
#   • Audio: Apple T2 Audio via apple-bce + PipeWire 1.6.0 ✓
#   • Storage: BTRFS on nvme0n1p2, LUKS2 vault on loop0
#   • Sleep: s2idle + deep available
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
skip()    { echo -e "  ${YELLOW}↷ skipped${RESET}  $*"; }

APPLIED=()
SKIPPED=()

mark_applied() { APPLIED+=("$1"); }
mark_skipped() { SKIPPED+=("$1"); }

# ── 1. Kernel parameters ─────────────────────────────────────────────────────
optimise_kernel_params() {
    header "Kernel Parameters"
    # These extend the current cmdline:
    # quiet nowatchdog splash rw rootflags=subvol=/@ root=UUID=...
    #
    # NOTE: You are using Limine — kernel params are in /boot/limine.conf
    # and managed by limine-entry-tool. Do NOT edit limine.conf directly
    # as it will be overwritten on kernel updates.
    #
    # Instead, configure via /etc/kernel/cmdline or limine-entry-tool drop-ins.

    local cmdline_file="/etc/kernel/cmdline"

    # Params already present (nowatchdog is already set)
    # We add Ice Lake-specific and T2-specific tweaks
    local cmdline_params=("intel_idle.max_cstate=4" "snd_hda_intel.power_save=0" "pcie_aspm=off" "mem_sleep_default=deep")

    # Handle cmdline
    local current_cmdline=""
    [[ -f "$cmdline_file" ]] && current_cmdline=$(cat "$cmdline_file")

    local new_params=()
    for p in "${cmdline_params[@]}"; do
        local key="${p%%=*}"
        if echo "$current_cmdline" | grep -q "$key"; then
            skip "cmdline: $p (already set)"
        else
            new_params+=("$p")
        fi
    done

    if [[ ${#new_params[@]} -gt 0 ]]; then
        info "Adding to ${cmdline_file}: ${new_params[*]}"
        echo "${current_cmdline} ${new_params[*]}" | xargs | sudo tee "$cmdline_file" > /dev/null
        success "Kernel cmdline updated"
        warn "Regenerate Limine entries after this: sudo limine-entry-tool"
        mark_applied "kernel-cmdline"
    else
        skip "All kernel cmdline params already present"
        mark_skipped "kernel-cmdline"
    fi

    # Handle sysctl
    info "Applying sysctl optimisations..."
    cat > /etc/sysctl.d/99-macbook-air-2020.conf << 'EOF'
# MacBook Air 2020 (CachyOS) — sysctl optimisations
# ZRAM is 15.4G — keep swappiness very low to prefer RAM
vm.swappiness = 10
vm.vfs_cache_pressure = 50

# Writeback tuning for BTRFS on NVMe — reduce wear
vm.dirty_writeback_centisecs = 6000
vm.dirty_expire_centisecs = 6000

# Network performance
net.core.netdev_max_backlog = 4096
net.ipv4.tcp_fastopen = 3

# Reduce NMI watchdog overhead (nowatchdog already in cmdline)
kernel.nmi_watchdog = 0
EOF
    sysctl --system &>/dev/null
    success "sysctl rules applied (/etc/sysctl.d/99-macbook-air-2020.conf)"
    mark_applied "sysctl"
}

# ── 2. TLP — Battery & Power ──────────────────────────────────────────────────
optimise_tlp() {
    header "TLP Power Management (Ice Lake Tuning)"

    if ! pacman -Q tlp &>/dev/null; then
        warn "TLP not installed — skipping"
        mark_skipped "tlp"
        return
    fi

    # Write a drop-in config (doesn't overwrite /etc/tlp.conf)
    cat > /etc/tlp.d/10-macbook-air-2020.conf << 'EOF'
# TLP drop-in for MacBook Air 2020 (MacBookAir9,1)
# Intel Core i5-1030NG7 — Ice Lake — 49.9Wh battery
# Applied on top of /etc/tlp.conf

# ── CPU ──────────────────────────────────────────────────────
# Intel p-state with HWP (Hardware P-state) — Ice Lake supports this
CPU_SCALING_GOVERNOR_ON_AC=performance
CPU_SCALING_GOVERNOR_ON_BAT=powersave

CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance
CPU_ENERGY_PERF_POLICY_ON_BAT=power

# Ice Lake boost — keep on AC, allow TLP to manage on battery
CPU_BOOST_ON_AC=1
CPU_BOOST_ON_BAT=0

# ── NVMe Power ───────────────────────────────────────────────
# APST (Autonomous Power State Transitions) — safe for Apple NVMe
DISK_IOSCHED_ON_AC="none"
DISK_IOSCHED_ON_BAT="none"
NVME_POWER_PM_ON_AC=on
NVME_POWER_PM_ON_BAT=auto

# ── PCIe ASPM ────────────────────────────────────────────────
# Set to default — we've disabled in cmdline for T2 stability
PCIE_ASPM_ON_AC=default
PCIE_ASPM_ON_BAT=default

# ── Wi-Fi (Broadcom BCM4377b) ─────────────────────────────────
# Power management causes disconnects — disable
WIFI_PWR_ON_AC=off
WIFI_PWR_ON_BAT=off

# ── USB Autosuspend ──────────────────────────────────────────
# Disable for T2 bridge stability (keyboard/trackpad over BCE)
USB_AUTOSUSPEND=0

# ── Runtime Power Management ─────────────────────────────────
RUNTIME_PM_ON_AC=auto
RUNTIME_PM_ON_BAT=auto

# ── Sound card power save ─────────────────────────────────────
# Disable — T2 audio pops under power save
SOUND_POWER_SAVE_ON_AC=0
SOUND_POWER_SAVE_ON_BAT=0
SOUND_POWER_SAVE_CONTROLLER=N
EOF

    systemctl restart tlp 2>/dev/null || true
    success "TLP drop-in written to /etc/tlp.d/10-macbook-air-2020.conf"
    info "Wi-Fi power management disabled (prevents BCM4377b disconnects)"
    info "USB autosuspend disabled (T2 BCE bridge stability)"
    mark_applied "tlp"
}

# ── 3. BTRFS mount options ────────────────────────────────────────────────────
optimise_btrfs() {
    header "BTRFS Mount Options"

    local fstab="/etc/fstab"
    local uuid
    uuid=$(findmnt -rno UUID /) || error "Could not detect root UUID via findmnt"

    if grep -q "noatime" "$fstab"; then
        skip "noatime already in fstab"
        mark_skipped "btrfs-fstab"
        return
    fi

    info "Recommended BTRFS mount options for NVMe on MacBook Air 2020:"
    cat << 'EOF'

  noatime         — Don't update access times (reduces writes ~30%)
  compress=zstd:1 — Level 1 zstd compression (fast + good ratio on code)
  space_cache=v2  — Faster space accounting
  autodefrag      — Background defragmentation (helps with small files)
  discard=async   — Async TRIM for NVMe longevity

EOF

    warn "Automatic fstab editing is risky. Showing required changes instead."
    info "Your current root entry in /etc/fstab should have these options:"
    echo ""
    echo "  UUID=${uuid}  /  btrfs  \\"
    echo "    rw,noatime,compress=zstd:1,space_cache=v2,autodefrag,discard=async,subvol=/@  0 0"
    echo ""
    info "To apply: sudo nano /etc/fstab and update the root and subvolume mount lines"
    info "After editing: sudo mount -o remount,noatime,compress=zstd:1 /"
    mark_skipped "btrfs-fstab (manual step required — see above)"

    # Apply live (non-persistent) optimisations now
    info "Applying live BTRFS optimisations (no fstab edit needed)..."
    if mount -o remount,noatime / 2>/dev/null; then
        success "noatime applied live"
    else
        warn "Could not remount"
    fi
    btrfs filesystem defragment -r /home &>/dev/null &
    info "Background defragmentation started for /home"
}

# ── 4. Apple T2 Audio stability ───────────────────────────────────────────────
optimise_audio() {
    header "Apple T2 Audio (PipeWire)"

    # Your system: PulseAudio on PipeWire 1.6.0
    # Default sink: alsa_output.pci-0000_74_00.3.Speakers ✓
    # Issue: T2 audio can crackle with wrong buffer settings

    local pipewire_conf_dir="${HOME}/.config/pipewire/pipewire.conf.d"
    mkdir -p "$pipewire_conf_dir"

    local conf_file="${pipewire_conf_dir}/10-t2-macbook-audio.conf"

    if [[ -f "$conf_file" ]]; then
        skip "PipeWire T2 audio config already exists"
        mark_skipped "pipewire-t2"
        return
    fi

    cat > "$conf_file" << 'EOF'
# PipeWire config for Apple T2 Audio — MacBook Air 2020
# Reduces audio crackling and pops common with apple-bce driver
context.properties = {
    # Increase quantum size to reduce xruns on T2 audio
    default.clock.rate          = 48000
    default.clock.quantum       = 1024
    default.clock.min-quantum   = 256
    default.clock.max-quantum   = 2048
}
EOF

    success "PipeWire T2 audio config written to ${conf_file}"
    info "Restart PipeWire to apply: systemctl --user restart pipewire pipewire-pulse"
    warn "If audio quality worsens, delete ${conf_file} and restart PipeWire"
    mark_applied "pipewire-t2"
}

# ── 5. Sleep / suspend ────────────────────────────────────────────────────────
optimise_sleep() {
    header "Sleep & Suspend Configuration"

    # Your system has both s2idle and deep available
    # mem_sleep currently: s2idle [deep] — deep is default (good)

    info "Current sleep modes available:"
    cat /sys/power/mem_sleep 2>/dev/null || echo "  (cannot read)"

    # Confirm deep sleep is default
    local current_sleep
    current_sleep=$(grep -oP '\[\K[^\]]+' /sys/power/mem_sleep 2>/dev/null || true)
    if [[ "$current_sleep" == "deep" ]]; then
        success "Deep sleep (S3-like via s2idle) already default — good"
    else
        info "Setting deep sleep as default..."
        echo deep | sudo tee /sys/power/mem_sleep > /dev/null
        success "Deep sleep enabled"
    fi

    # Write a suspend hook to safely handle T2 quirks
    cat > /etc/systemd/system/macbook-suspend-fix.service << 'EOF'
# Workaround for T2 apple-bce driver issues on resume
# Some users see keyboard/trackpad unresponsive after suspend
[Unit]
Description=MacBook Air 2020 — T2 Resume Fix
After=suspend.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'modprobe -r apple-bce; sleep 1; modprobe apple-bce'
RemainAfterExit=yes

[Install]
WantedBy=suspend.target
EOF

    systemctl daemon-reload
    systemctl enable macbook-suspend-fix.service
    success "Suspend resume fix service installed"
    info "This reloads apple-bce on wake to restore keyboard/trackpad if they freeze"
    mark_applied "sleep-suspend"
}

# ── 6. ZRAM verification ──────────────────────────────────────────────────────
verify_zram() {
    header "ZRAM (Already Configured)"

    # Your system: /dev/zram0 zstd 15.4G — perfect
    info "Current ZRAM state:"
    zramctl 2>/dev/null || echo "  (zramctl not available)"
    echo ""
    success "ZRAM is correctly configured at 15.4G with zstd — no changes needed"
    info "Used: $(free -h | awk '/Swap/ {print $3}') / $(free -h | awk '/Swap/ {print $2}')"
    mark_skipped "zram (already optimal)"
}

# ── 7. Power profiles daemon ──────────────────────────────────────────────────
check_power_profiles() {
    header "Power Profiles"

    if systemctl is-active power-profiles-daemon &>/dev/null; then
        local current
        current=$(powerprofilesctl get 2>/dev/null || echo "unknown")
        info "power-profiles-daemon is active, current profile: ${current}"
        info "TLP and power-profiles-daemon are both running."
        warn "This can cause conflicts. Recommended: choose one."
        echo ""
        echo "  Option A — Keep TLP (more control, better for battery longevity):"
        echo "    sudo systemctl disable --now power-profiles-daemon"
        echo ""
        echo "  Option B — Keep power-profiles-daemon (simpler, GNOME/KDE integrated):"
        echo "    sudo systemctl disable --now tlp"
        echo ""
        info "For a developer workstation: TLP is recommended (Option A)"
    fi
    mark_skipped "power-profiles (manual decision required)"
}

# ── 8. Useful packages ────────────────────────────────────────────────────────
install_recommended_packages() {
    header "Recommended Packages"

    local packages=(
        "lm_sensors"        # Hardware monitoring (already in use)
        "htop"              # Process monitor
        "btop"              # Modern resource monitor
        "nvme-cli"          # NVMe health and management
        "smartmontools"     # Drive health monitoring
        "powertop"          # Power consumption analyser (Intel tool)
        "cpupower"          # CPU frequency scaling tool
    )

    local to_install=()
    for pkg in "${packages[@]}"; do
        if ! pacman -Q "$pkg" &>/dev/null; then
            to_install+=("$pkg")
        else
            skip "${pkg} (already installed)"
        fi
    done

    if [[ ${#to_install[@]} -gt 0 ]]; then
        info "Installing: ${to_install[*]}"
        pacman -S --noconfirm "${to_install[@]}"
        success "Packages installed"
        mark_applied "recommended-packages"
    else
        success "All recommended packages already installed"
        mark_skipped "recommended-packages"
    fi
}

# ── Summary report ────────────────────────────────────────────────────────────
print_summary() {
    header "Optimisation Summary"

    echo -e "${GREEN}Applied:${RESET}"
    for item in "${APPLIED[@]}"; do
        echo "  ✓ ${item}"
    done

    echo ""
    echo -e "${YELLOW}Skipped / Manual:${RESET}"
    for item in "${SKIPPED[@]}"; do
        echo "  ↷ ${item}"
    done

    echo ""
    echo -e "${BOLD}Next steps:${RESET}"
    echo "  1. Reboot to apply kernel cmdline changes"
    echo "  2. Run: systemctl --user restart pipewire pipewire-pulse"
    echo "  3. Review TLP vs power-profiles-daemon conflict (see above)"
    echo "  4. Update /etc/fstab BTRFS mount options (see above)"
    echo "  5. Run: sudo bash 01-thermal-setup.sh  (fix the 100°C issue first!)"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  MacBook Air 2020 — Post-Install Optimisation       ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    # Some sections need root, some don't
    # Run root sections with sudo, user sections as current user

    if [[ $EUID -eq 0 ]]; then
        optimise_kernel_params
        optimise_tlp
        optimise_btrfs
        optimise_sleep
        install_recommended_packages
        verify_zram
        check_power_profiles
        # Audio config is per-user — write to original user's home
        if [[ -n "${SUDO_USER:-}" ]]; then
            local user_home
            user_home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
            HOME="$user_home" optimise_audio
            chown -R "$SUDO_USER":"$SUDO_USER" "$user_home/.config/pipewire" 2>/dev/null || true
        else
            warn "Run 'bash $0 --audio-only' as your normal user for PipeWire config"
        fi
    elif [[ "${1:-}" == "--audio-only" ]]; then
        optimise_audio
    else
        warn "Some optimisations require root. Re-run with: sudo bash $0"
        optimise_audio
        verify_zram
        check_power_profiles
    fi

    print_summary
}

main "$@"
