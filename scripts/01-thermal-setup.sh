#!/usr/bin/env bash
# =============================================================================
# 01-thermal-setup.sh
# Fan & Thermal Management for MacBook Air 2020 (MacBookAir9,1) on CachyOS
#
# Problem: thermald alone does NOT drive applesmc fan correctly on T2 Macs.
#          This script installs and configures mbpfan to read Apple SMC sensors
#          and control fan speed, preventing the CPU from hitting 100°C at idle.
#
# Hardware confirmed:
#   Fan:     applesmc fan1 (2700–8000 RPM)
#   Sensors: TC0C (CPU core), TCGC (GPU), TB0T (battery), TC0P (proximity)
#   Kernel:  6.19.x-cachyos  |  Driver: applesmc
# =============================================================================

set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
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

# ── Preflight checks ──────────────────────────────────────────────────────────
preflight() {
    header "Preflight Checks"

    # Locate Apple fan/SMC sysfs path using find (safe across all shells)
    local path1 path2
    path1=$(find /sys/devices/platform -maxdepth 1 -name "applesmc*" -type d 2>/dev/null | head -1)
    path2=$(find /sys/devices/LNXSYSTM:00 -maxdepth 5 -name "APP0001:00" -type d 2>/dev/null | head -1)
    APPLESMC_PATH="${path1:-$path2}"

    if [[ -n "$APPLESMC_PATH" ]]; then
        export APPLESMC_PATH
        success "Apple fan device found at ${APPLESMC_PATH}"
    else
        warn "Apple fan sysfs path not found — fan speed reads skipped"
        warn "mbpfan will still control the fan via coretemp sensors"
    fi

    # Show current temps
    info "Current temperatures:"
    sensors 2>/dev/null | grep -E "^(Package|Core)" | head -8 || warn "sensors not available"

    # Show fan speed only if we have the path and file exists
    if [[ -n "$APPLESMC_PATH" ]] && [[ -f "${APPLESMC_PATH}/fan1_output" ]]; then
        info "Current fan speed: $(cat "${APPLESMC_PATH}/fan1_output") RPM"
    fi
}

# ── Install mbpfan ────────────────────────────────────────────────────────────
install_mbpfan() {
    header "Installing mbpfan"

    if pacman -Q mbpfan &>/dev/null; then
        success "mbpfan already installed — skipping"
    else
        info "Installing mbpfan from AUR via paru/yay..."
        info "You may be prompted for your password."
        # AUR helpers must run as normal user, not via sudo
        local aur_user="${SUDO_USER:-$USER}"
        if command -v paru &>/dev/null; then
            su -c "paru -S --noconfirm mbpfan" "$aur_user"
        elif command -v yay &>/dev/null; then
            su -c "yay -S --noconfirm mbpfan" "$aur_user"
        else
            error "No AUR helper found. Install with: paru -S mbpfan"
        fi
        success "mbpfan installed"
    fi
}

# ── Write mbpfan config ───────────────────────────────────────────────────────
configure_mbpfan() {
    header "Writing /etc/mbpfan.conf"

    # Back up any existing config
    [[ -f /etc/mbpfan.conf ]] && cp /etc/mbpfan.conf /etc/mbpfan.conf.bak
    info "Backup saved to /etc/mbpfan.conf.bak (if existed)"

    cat > /etc/mbpfan.conf << 'EOF'
# /etc/mbpfan.conf
# Tuned for MacBook Air 2020 (MacBookAir9,1) — Intel Core i5-1030NG7
# Fan sysfs path: /sys/devices/LNXSYSTM:.../APP0001:00/
# Sensors confirmed: coretemp (Package id 0, Core 0-3)
#
# Strategy:
#   • Below 55°C  → minimum speed (quiet)
#   • 55–70°C     → linear ramp (normal use)
#   • 70–85°C     → aggressive ramp (heavy load)
#   • Above 85°C  → maximum speed (thermal protection)

[general]
# Poll interval in seconds
poll_interval = 3

[fan]
# Fan identifier
fan_id = 1

# Hardware limits for MacBook Air 2020 fan
min_speed = 2700
max_speed = 8000

# Idle fan speed — keep some airflow even at rest
low_temp        = 55
low_temp_speed  = 2700

# Moderate load — normal working temperatures
mid_temp        = 70
mid_temp_speed  = 4500

# Heavy load threshold — coding/compiling
high_temp       = 80
high_temp_speed = 6500

# Critical — max fan to protect hardware
max_temp        = 85
max_temp_speed  = 8000

# Hysteresis: don't reduce fan until temp drops this many degrees below threshold
temp_change_factor = 4
EOF

    success "Config written to /etc/mbpfan.conf"
}

# ── Disable conflicting thermald ──────────────────────────────────────────────
handle_thermald() {
    header "Configuring thermald (disable fan control, keep RAPL)"

    # thermald is useful for Intel RAPL power limits but fights with mbpfan
    # We keep it enabled but tell it not to control the fan
    if systemctl is-enabled thermald &>/dev/null; then
        info "thermald is enabled — it will coexist with mbpfan"
        info "(thermald handles Intel RAPL power capping; mbpfan handles fan)"
        warn "If fans still misbehave after this script, try: sudo systemctl disable --now thermald"
    fi

    # Write a custom thermald XML that avoids fan control zones
    mkdir -p /etc/thermald
    if [[ ! -f /etc/thermald/thermal-conf.xml ]]; then
        cat > /etc/thermald/thermal-conf.xml << 'EOF'
<?xml version="1.0"?>
<!--
  thermald config for MacBook Air 2020 on CachyOS
  Strategy: Use only Intel RAPL (power capping) — leave fan to mbpfan
  This prevents thermald from fighting mbpfan for fan control.
-->
<ThermalConfiguration>
  <Platform>
    <Name>MacBook Air 2020 Intel</Name>
    <ProductName>MacBookAir9,1</ProductName>
    <Preference>QUIET</Preference>
    <ThermalZones>
      <ThermalZone>
        <Type>x86_pkg_temp</Type>
        <TripPoints>
          <!-- Only use RAPL power limit, not fan control -->
          <TripPoint>
            <SensorType>x86_pkg_temp</SensorType>
            <Temperature>85000</Temperature>
            <type>passive</type>
            <ControlType>SEQUENTIAL</ControlType>
            <CoolingDevice>
              <index>1</index>
              <type>rapl_controller</type>
              <influence>100</influence>
              <SamplingPeriod>3</SamplingPeriod>
            </CoolingDevice>
          </TripPoint>
        </TripPoints>
      </ThermalZone>
    </ThermalZones>
  </Platform>
</ThermalConfiguration>
EOF
        success "thermald config written — RAPL-only, fan left to mbpfan"
    else
        warn "/etc/thermald/thermal-conf.xml already exists — not overwriting"
        warn "Review it manually to ensure no fan cooling devices are listed"
    fi
}

# ── Enable & start mbpfan ─────────────────────────────────────────────────────
enable_services() {
    header "Enabling Services"

    # Restart thermald with new config
    systemctl restart thermald || warn "thermald restart failed — continuing"

    # Enable and start mbpfan
    systemctl enable --now mbpfan
    sleep 2

    if systemctl is-active mbpfan &>/dev/null; then
        success "mbpfan is active"
    else
        error "mbpfan failed to start. Check: sudo journalctl -u mbpfan -n 50"
    fi
}

# ── Verify ────────────────────────────────────────────────────────────────────
verify() {
    header "Verification"

    info "Fan speed (should start rising within 30s if hot):"
    # Use find to avoid fish shell glob failures
    APPLESMC_PATH=${APPLESMC_PATH:-$(find /sys/devices/platform -maxdepth 1 -name "applesmc*" -type d 2>/dev/null | head -1)}
    APPLESMC_PATH=${APPLESMC_PATH:-$(find /sys/devices/LNXSYSTM:00 -maxdepth 5 -name "APP0001:00" -type d 2>/dev/null | head -1)}
    if [[ -n "$APPLESMC_PATH" ]] && [[ -f "${APPLESMC_PATH}/fan1_output" ]]; then
        echo "  fan1: $(cat "${APPLESMC_PATH}/fan1_output") RPM"
    else
        echo "  (cannot read fan speed directly)"
    fi

    info "mbpfan service status:"
    systemctl status mbpfan --no-pager -l | head -15

    info "Current temperatures:"
    sensors 2>/dev/null | grep -E "(Package|Core [0-9]|TCMX|TC0P)" | head -8 || true

    echo ""
    success "Thermal setup complete!"
    echo -e "${YELLOW}Monitor temps for 2 minutes with:${RESET}"
    echo "  watch -n 2 'sensors | grep -E \"Package|fan1\"'"
    echo ""
    echo -e "${YELLOW}Expected behaviour:${RESET}"
    echo "  • Under 55°C  → ~2700 RPM (near-silent)"
    echo "  • Under heavy load → fan ramps to 6500–8000 RPM"
    echo "  • Temperatures should NOT exceed 90°C under normal use"
}

# ── Main ──────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}${CYAN}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║  MacBook Air 2020 — Fan & Thermal Setup (CachyOS)   ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    require_root
    preflight
    install_mbpfan
    configure_mbpfan
    handle_thermald
    enable_services
    verify
}

main "$@"
