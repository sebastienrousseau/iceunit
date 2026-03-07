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

    # Confirm we're on a T2 MacBook
    if ! ls /sys/devices/platform/applesmc.768/ &>/dev/null; then
        error "applesmc not found. Is apple-bce loaded? Try: sudo modprobe apple-bce"
    fi
    success "applesmc device found"

    # Show current temps so user understands the urgency
    info "Current temperatures:"
    sensors 2>/dev/null | grep -E "^(Package|Core|TC[0-9])" | head -10 || true

    info "Current fan speed:"
    cat /sys/devices/platform/applesmc.768/fan1_output 2>/dev/null \
        && echo " RPM (current)" || warn "Could not read fan speed directly"
}

# ── Install mbpfan ────────────────────────────────────────────────────────────
install_mbpfan() {
    header "Installing mbpfan"

    if pacman -Q mbpfan &>/dev/null; then
        success "mbpfan already installed — skipping"
    else
        info "Installing mbpfan from AUR via paru/yay..."
        # Try paru first, then yay, then error
        if command -v paru &>/dev/null; then
            sudo -u "${SUDO_USER:-$USER}" paru -S --noconfirm mbpfan
        elif command -v yay &>/dev/null; then
            sudo -u "${SUDO_USER:-$USER}" yay -S --noconfirm mbpfan
        else
            error "No AUR helper found. Install paru: sudo pacman -S paru"
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
# applesmc fan1: 2700–8000 RPM
# Sensors confirmed present: coretemp + applesmc TC* probes
#
# Strategy:
#   • Below 55°C  → minimum speed (quiet)
#   • 55–70°C     → linear ramp (normal use)
#   • 70–85°C     → aggressive ramp (heavy load)
#   • Above 85°C  → maximum speed (thermal protection)

[general]
# Poll interval in seconds
poll_interval = 3

# Read from both coretemp and applesmc
# applesmc TCMX = max of all CPU core sensors (most reliable on T2)
sensors = [
    coretemp-isa-0000/Package id 0,
    applesmc-acpi-0/TCMX,
    applesmc-acpi-0/TC0P
]

[fan]
# Fan identifier (check: ls /sys/devices/platform/applesmc.768/fan*_*)
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
# Prevents rapid fan speed oscillation
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
    cat /sys/devices/platform/applesmc.768/fan1_output 2>/dev/null \
        | xargs -I{} echo "  fan1: {} RPM" || echo "  (cannot read directly)"

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
