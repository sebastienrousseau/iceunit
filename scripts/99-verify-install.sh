#!/usr/bin/env bash
# =============================================================================
# 99-verify-install.sh
# Clean, professional audit script matching the Iceunit (ICU) design.
# =============================================================================

set -uo pipefail

# Iceunit Color Palette (ANSI equivalents)
CHECK="\033[0;32m✓\033[0m"
CROSS="\033[0;31m✗\033[0m"
PENDING="\033[1;35m>\033[0m"
LABEL="\033[1m"        # Bold
DIM="\033[38;5;241m"
YELLOW="\033[1;33m"
PURPLE="\033[1;35m"
HEADER="\033[1;36m"
RESET="\033[0m"

# Detect real user's home even if running with sudo
REAL_USER="${SUDO_USER:-${USER:-$(whoami)}}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

check() {
    local category="$1"
    local software="$2"
    local cmd="$3"
    local status_msg="${4:-}"
    
    if eval "$cmd" >/dev/null 2>&1; then
        printf "  %b %b %b\n" "$CHECK" "${LABEL}${category}${RESET}" "${DIM}(${software})${RESET}"
        return 0
    else
        if [[ "$status_msg" == *"Reboot"* ]] || [[ "$status_msg" == *"pending"* ]]; then
            printf "  %b %b%s (%s) %s%b\n" "$PENDING" "$PURPLE" "$category" "$software" "$status_msg" "$RESET"
        else
            printf "  %b %b %b %b\n" "$CROSS" "${LABEL}${category}${RESET}" "${DIM}(${software})${RESET}" "${YELLOW}${status_msg}${RESET}"
        fi
        return 1
    fi
}

header() {
    printf "\n%b%s%b\n" "$HEADER" "$1" "$RESET"
}

# ── 1. PACKAGES ──────────────────────────────────────────────────────────────
header "Package Verification"
PKGS=(bc lm_sensors htop btop nvme-cli smartmontools powertop cpupower tlp pipewire pipewire-pulse wireplumber limine efibootmgr refind snapper btrfs-progs cryptsetup git curl wget base-devel ripgrep fd fzf bat eza jq yq neovim tmux zoxide atuin direnv starship podman podman-compose python python-pip python-pipx nodejs npm go rust cmake ninja gcc clang mold lazygit github-cli ollama kubectl helm k9s terraform ansible stern dive rsync gitleaks age sops openssh gnupg ufw)

MISSING_COUNT=0
for pkg in "${PKGS[@]}"; do
    if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
        ((MISSING_COUNT++))
    fi
done

if [ "$MISSING_COUNT" -eq 0 ]; then
    printf "  %b %b %b\n" "$CHECK" "${LABEL}Core Packages${RESET}" "${DIM}(All ${#PKGS[@]} Iceunit packages present)${RESET}"
else
    printf "  %b %b %b\n" "$CROSS" "${LABEL}Core Packages${RESET}" "${DIM}($MISSING_COUNT packages missing)${RESET}"
fi

# ── 2. SERVICES ──────────────────────────────────────────────────────────────
header "Service Verification"
check "Thermal Control" "mbpfan" "systemctl is-active mbpfan"

# TLP vs PPD check: Success if TLP is active OR if PPD is masked
TLP_ACTIVE="systemctl is-active tlp"
PPD_MASKED="systemctl is-enabled power-profiles-daemon | grep -q masked"
if eval "$TLP_ACTIVE" >/dev/null 2>&1; then
    check "Power Management" "TLP" "true"
elif eval "$PPD_MASKED" >/dev/null 2>&1; then
    check "Power Management" "TLP (pending start)" "false" "Reboot to activate"
else
    check "Power Management" "TLP" "false" "TLP recommended"
fi

check "Security" "UFW Firewall" "systemctl is-active ufw"

# Containers check
if systemctl is-active docker >/dev/null 2>&1; then
    check "Containers" "Docker" "true"
elif systemctl is-active podman >/dev/null 2>&1 || systemctl is-active podman.socket >/dev/null 2>&1; then
    check "Containers" "Podman" "true"
elif command -v podman >/dev/null 2>&1; then
    check "Containers" "Podman (daemonless)" "true"
else
    check "Containers" "Docker/Podman" "false"
fi

# ── 3. OPTIMISATION ──────────────────────────────────────────────────────────
header "Hardware Optimisation"
check "Thermal Curve" "/etc/mbpfan.conf" "[ -f /etc/mbpfan.conf ]"
check "System Performance" "Sysctl Tweaks" "[ -f /etc/sysctl.d/99-macbook-air-2020.conf ]"
check "Power Profile" "TLP Config" "[ -f /etc/tlp.d/10-macbook-air-2020.conf ]"

# Intelligent kernel check
KERNEL_SET="grep -q 'intel_idle.max_cstate=4' /etc/kernel/cmdline"
KERNEL_ACTIVE="grep -q 'intel_idle.max_cstate=4' /proc/cmdline"
if eval "$KERNEL_ACTIVE" >/dev/null 2>&1; then
    check "T2 Compatibility" "Kernel Params" "true"
elif eval "$KERNEL_SET" >/dev/null 2>&1; then
    check "T2 Compatibility" "Kernel Config" "false" "Reboot required"
else
    check "T2 Compatibility" "Kernel Params" "false"
fi

check "Sleep Mode" "Deep Sleep" "grep -q '\[deep\]' /sys/power/mem_sleep"

# ── 4. FIRMWARE & STORAGE ────────────────────────────────────────────────────
header "Firmware & Storage"
check "Wi-Fi Driver" "BCM4377b" "[ -f /lib/firmware/brcm/brcmfmac4377b3-pcie.apple,fiji.bin ]"
check "Bluetooth Driver" "BRCM4377" "[ -f /lib/firmware/brcm/brcmbt4377b3-apple,formosa.bin ]"

VAULT_FOUND=0
[ -f "$REAL_HOME/.vault.img" ] && VAULT_FOUND=1
[ -f "$REAL_HOME/Code.img" ] && VAULT_FOUND=1
[ -f "/root/.vault.img" ] && VAULT_FOUND=1

if [ "$VAULT_FOUND" -eq 1 ]; then
    check "Code Vault" "Image found" "true"
else
    check "Code Vault" "Missing image" "false"
fi

check "Vault Mounting" "\$HOME/Code" "findmnt -rno TARGET $REAL_HOME/Code || findmnt -rno TARGET /root/Code"

printf "\n%bVerification Complete.%b\n" "$LABEL" "$RESET"
printf "Run %bsudo make install%b to fix any issues.\n\n" "$HEADER" "$RESET"
