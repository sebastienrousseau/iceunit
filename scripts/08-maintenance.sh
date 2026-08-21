#!/usr/bin/env bash
# =============================================================================
# 08-maintenance.sh
# Periodic Maintenance for MacBook Air 2020 (MacBookAir9,1) on CachyOS
#
# Problem: Day-to-day system health degrades without periodic upkeep —
#          stale caches, orphaned packages, journal bloat, and unchecked
#          T2 hardware state can accumulate silently on a rolling distro.
#
# This script performs a safe "spring-clean" across system updates,
# T2 hardware health, SSD TRIM, package cache, orphan removal,
# failed unit detection, journal vacuuming, bootloader integrity,
# and git signing readiness.
#
# Hardware confirmed:
#   Model:   MacBook Air 2020 (MacBookAir9,1) — NO Touch Bar
#   Kernel:  6.19.x-cachyos  |  Driver: apple_bce (T2 bridge)
#   Boot:    Limine (not GRUB)
#   Storage: BTRFS on NVMe, LUKS2 vault
# =============================================================================

set -Eeuo pipefail

DRY_RUN=false
for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
    [[ "$arg" == "--help" || "$arg" == "-h" ]] && {
        echo "Usage: sudo bash $0 [--dry-run] [--help]"
        echo "Periodic maintenance for MacBook Air 2020 on CachyOS."
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
    [[ $EUID -eq 0 ]] || error "Run with sudo: sudo bash $0"
}

# ── 1. System Upgrade ────────────────────────────────────────────────────────
system_upgrade() {
    header "System Upgrade"

    # Skip ranking if mirrorlist was refreshed within the last 24 hours
    local _mirrorlist="/etc/pacman.d/mirrorlist"
    local _mirror_ttl=$((24 * 3600))
    local _mirror_fresh=false
    if [[ -f "$_mirrorlist" ]]; then
        local _mirror_age=$(( $(date +%s) - $(stat -c %Y "$_mirrorlist") ))
        (( _mirror_age < _mirror_ttl )) && _mirror_fresh=true
    fi

    if $_mirror_fresh; then
        info "Mirrorlist is fresh ($((  _mirror_age / 3600 ))h old) — skipping ranking"
    elif command -v cachyos-rate-mirrors &>/dev/null; then
        info "Ranking mirrors via cachyos-rate-mirrors..."
        dryrun cachyos-rate-mirrors
    elif command -v rate-mirrors &>/dev/null; then
        info "Ranking mirrors via rate-mirrors..."
        dryrun bash -c 'rate-mirrors --protocol https arch | sudo tee /etc/pacman.d/mirrorlist > /dev/null'
    elif command -v reflector &>/dev/null; then
        info "Ranking mirrors via reflector..."
        dryrun reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    else
        info "No mirror ranker found — using existing mirrorlist"
    fi  # end mirror ranking

    local aur_user="${SUDO_USER:-$USER}"
    if command -v paru &>/dev/null; then
        info "Running full system upgrade via paru..."
        dryrun runuser -l "$aur_user" -- paru -Syu --noconfirm
    elif command -v yay &>/dev/null; then
        info "Running full system upgrade via yay..."
        dryrun runuser -l "$aur_user" -- yay -Syu --noconfirm
    else
        info "No AUR helper found — falling back to pacman..."
        dryrun pacman -Syu --noconfirm
    fi
    success "System upgrade complete"
    mark_applied "system-upgrade"
}

# ── 2. T2 Hardware Health ────────────────────────────────────────────────────
t2_health() {
    header "T2 Hardware Health"

    # Check apple_bce module (T2 bridge for keyboard/trackpad/audio)
    if lsmod | grep -q apple_bce; then
        success "apple_bce module loaded (T2 bridge active)"
    else
        warn "apple_bce module NOT loaded — keyboard/trackpad may not work after reboot"
    fi

    # Check mbpfan service
    if systemctl is-active mbpfan &>/dev/null; then
        success "mbpfan is active"
    else
        warn "mbpfan is not running — fan control may be degraded"
    fi

    # Read fan speed from sysfs using find (safe across all shells)
    local smc_path
    smc_path=$(find /sys/devices/platform -maxdepth 1 -name "applesmc*" -type d 2>/dev/null | head -1)
    smc_path="${smc_path:-$(find /sys/devices/LNXSYSTM:00 -maxdepth 5 -name "APP0001:00" -type d 2>/dev/null | head -1)}"
    if [[ -n "$smc_path" ]] && [[ -f "${smc_path}/fan1_output" ]]; then
        info "Current fan speed: $(cat "${smc_path}/fan1_output") RPM"
    else
        info "Fan speed not readable from sysfs"
    fi

    mark_applied "t2-health"
}

# ── 3. SSD TRIM ─────────────────────────────────────────────────────────────
ssd_trim() {
    header "SSD TRIM"

    info "Running filesystem TRIM on all mounted volumes..."
    dryrun fstrim -va
    success "TRIM complete"
    mark_applied "ssd-trim"
}

# ── 4. Package Cache Cleanup ────────────────────────────────────────────────
package_cache_cleanup() {
    header "Package Cache Cleanup"

    if ! command -v paccache &>/dev/null; then
        skip "paccache not found (install pacman-contrib)"
        mark_skipped "package-cache"
        return
    fi

    info "Keeping last 2 versions of installed packages..."
    dryrun paccache -rk2
    info "Removing all cached versions of uninstalled packages..."
    dryrun paccache -ruk0
    success "Package cache cleaned"
    mark_applied "package-cache"
}

# ── 5. Orphan Removal ───────────────────────────────────────────────────────
orphan_removal() {
    header "Orphan Removal"

    local -a orphans=()
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && orphans+=("$pkg")
    done < <(pacman -Qtdq 2>/dev/null || true)

    if [[ ${#orphans[@]} -eq 0 ]]; then
        success "No orphaned packages found"
        mark_skipped "orphan-removal"
        return
    fi

    info "Found orphaned packages:"
    printf '  %s\n' "${orphans[@]}"
    dryrun pacman -Rns --noconfirm "${orphans[@]}"
    success "Orphans removed"
    mark_applied "orphan-removal"
}

# ── 6. Failed Systemd Units ─────────────────────────────────────────────────
failed_units() {
    header "Failed Systemd Units"

    local failed
    failed=$(systemctl --failed --no-pager --no-legend 2>/dev/null || true)

    if [[ -z "$failed" ]]; then
        success "No failed systemd units"
    else
        warn "Failed units detected:"
        echo "$failed"
    fi

    mark_applied "failed-units"
}

# ── 7. Journal Vacuum ───────────────────────────────────────────────────────
journal_vacuum() {
    header "Journal Vacuum"

    info "Vacuuming journal entries older than 3 days..."
    dryrun journalctl --vacuum-time=3d
    success "Journal vacuumed"
    mark_applied "journal-vacuum"
}

# ── 8. Limine Bootloader Integrity ──────────────────────────────────────────
limine_integrity() {
    header "Limine Bootloader Integrity"

    # Verify limine package is installed
    if pacman -Q limine &>/dev/null; then
        success "limine package installed"
    else
        warn "limine package not found"
        mark_skipped "limine-integrity"
        return
    fi

    # Verify limine.conf exists
    if [[ -f /boot/limine.conf ]]; then
        success "limine.conf found at /boot/limine.conf"
    else
        warn "limine.conf not found at /boot/limine.conf"
        mark_skipped "limine-integrity"
        return
    fi

    # Check for a kernel entry in limine.conf
    if grep -q "vmlinuz" /boot/limine.conf 2>/dev/null; then
        success "Kernel entry found in limine.conf"
    else
        warn "No kernel entry (vmlinuz) found in limine.conf"
    fi

    # Check limine-entry-tool availability
    if command -v limine-entry-tool &>/dev/null; then
        success "limine-entry-tool available"
    else
        info "limine-entry-tool not found (entries managed manually)"
    fi

    mark_applied "limine-integrity"
}

# ── 9. Git Signing Readiness ────────────────────────────────────────────────
git_signing() {
    header "Git Signing Readiness"

    local real_user="${SUDO_USER:-$USER}"

    # Check GPG agent
    if pgrep -u "$real_user" gpg-agent &>/dev/null; then
        success "GPG agent running for ${real_user}"
    else
        info "GPG agent not running (will start on demand)"
    fi

    # Check signing key
    local signing_key
    signing_key=$(runuser -l "$real_user" -- git config --get user.signingkey 2>/dev/null || true)
    if [[ -n "$signing_key" ]]; then
        success "Git signing key configured: ${signing_key}"
    else
        warn "No git signing key configured"
    fi

    # Check commit.gpgsign
    local gpgsign
    gpgsign=$(runuser -l "$real_user" -- git config --get commit.gpgsign 2>/dev/null || true)
    if [[ "$gpgsign" == "true" ]]; then
        success "commit.gpgsign is enabled"
    else
        warn "commit.gpgsign is not enabled"
    fi

    # Ensure GPG agent caches passphrase for extended sessions
    local real_home
    real_home=$(getent passwd "$real_user" | cut -d: -f6)
    local gpg_agent_conf="${real_home}/.gnupg/gpg-agent.conf"
    if [[ -f "$gpg_agent_conf" ]] && grep -q "max-cache-ttl" "$gpg_agent_conf" 2>/dev/null; then
        success "GPG agent cache TTL already configured"
    else
        info "Configuring GPG agent passphrase cache (7-day TTL)..."
        dryrun mkdir -p "${real_home}/.gnupg"
        if ! $DRY_RUN; then
            {
                echo ""
                echo "# Extended passphrase cache for developer workflow"
                echo "default-cache-ttl 604800"
                echo "max-cache-ttl 604800"
            } >> "$gpg_agent_conf"
            chown "$real_user":"$real_user" "$gpg_agent_conf"
            chmod 600 "$gpg_agent_conf"
        else
            echo "[DRY-RUN] append cache-ttl settings to $gpg_agent_conf"
        fi
        success "GPG agent cache TTL set to 7 days"
    fi

    mark_applied "git-signing"
}

# ── Summary report ───────────────────────────────────────────────────────────
print_summary() {
    header "Maintenance Summary"

    if [[ ${#APPLIED[@]} -gt 0 ]]; then
        echo -e "${GREEN}Completed:${RESET}"
        for item in "${APPLIED[@]}"; do
            echo "  + ${item}"
        done
    fi

    if [[ ${#SKIPPED[@]} -gt 0 ]]; then
        echo ""
        echo -e "${YELLOW}Skipped:${RESET}"
        for item in "${SKIPPED[@]}"; do
            echo "  -> ${item}"
        done
    fi

    echo ""
    success "Periodic maintenance complete"
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}${CYAN}"
    echo "+==============================================+"
    echo "|  MacBook Air 2020 -- Periodic Maintenance    |"
    echo "+==============================================+"
    echo -e "${RESET}"

    require_root
    system_upgrade
    t2_health
    ssd_trim
    package_cache_cleanup
    orphan_removal
    failed_units
    journal_vacuum
    limine_integrity
    git_signing
    print_summary
}

main "$@"
