#!/usr/bin/env bash
# =============================================================================
# 99-verify-install.sh
# Clean, professional audit script matching the Iceunit (ICU) design.
# =============================================================================

# Handle flags before strict mode
AUTO_FIX=false
for arg in "$@"; do
    [[ "$arg" == "--auto-fix" ]] && AUTO_FIX=true
    [[ "$arg" == "--help" || "$arg" == "-h" ]] && {
        echo "Usage: bash $0 [--auto-fix] [--help]"
        echo "Verify the health of the entire Iceunit installation."
        echo ""
        echo "Flags:"
        echo "  --auto-fix   Automatically run fix scripts for failed checks"
        echo "  --help       Show this help message"
        exit 0
    }
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Auto-fix tracking: map categories to fix scripts
declare -A FIX_SCRIPTS
FIX_SCRIPTS=(
    [packages]="sudo bash ${SCRIPT_DIR}/00-system-init.sh --yes"
    [thermal]="sudo bash ${SCRIPT_DIR}/01-thermal-setup.sh"
    [optimise]="sudo bash ${SCRIPT_DIR}/03-optimise.sh --yes"
    [vault]="bash ${SCRIPT_DIR}/05-mount-vault.sh"
    [maintenance]="sudo bash ${SCRIPT_DIR}/08-maintenance.sh"
    [desktop]="sudo bash ${SCRIPT_DIR}/../workstation/05-desktop-base.sh"
)
FIX_NEEDED=()

auto_fix_mark() {
    local category="$1"
    if [[ -n "${FIX_SCRIPTS[$category]:-}" ]]; then
        # Only add if not already in the list
        local already=false
        for f in "${FIX_NEEDED[@]}"; do
            [[ "$f" == "$category" ]] && already=true
        done
        $already || FIX_NEEDED+=("$category")
    fi
}

# NOTE: -e is intentionally omitted — the check() function uses eval in
# conditionals that return non-zero for missing/inactive items. With -e
# the script would exit on the first failing check instead of reporting all.
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
# Core mandatory packages (excluding optional container choice)
PKGS=(bc lm_sensors htop btop nvme-cli smartmontools powertop cpupower tlp pipewire pipewire-pulse wireplumber limine efibootmgr refind snapper btrfs-progs cryptsetup git curl wget base-devel ripgrep fd fzf bat eza jq yq neovim tmux zoxide atuin direnv starship python python-pip python-pipx nodejs npm go rust cmake ninja gcc clang mold lazygit github-cli ollama kubectl helm k9s terraform ansible stern dive rsync gitleaks age sops openssh gnupg ufw)

declare -A _INSTALLED
while IFS= read -r p; do
    [[ -n "$p" ]] && _INSTALLED["$p"]=1
done < <(pacman -Qq "${PKGS[@]}" 2>/dev/null)

MISSING_PKGS=()
for pkg in "${PKGS[@]}"; do
    [[ -z "${_INSTALLED[$pkg]:-}" ]] && MISSING_PKGS+=("$pkg")
done

MISSING_COUNT=${#MISSING_PKGS[@]}

if [ "$MISSING_COUNT" -eq 0 ]; then
    printf "  %b %b %b\n" "$CHECK" "${LABEL}Core Packages${RESET}" "${DIM}(All ${#PKGS[@]} Iceunit packages present)${RESET}"
else
    MISSING_STR="${MISSING_PKGS[*]}"
    printf "  %b %b %b %b\n" "$CROSS" "${LABEL}Core Packages${RESET}" "${DIM}($MISSING_COUNT missing)${RESET}" "${YELLOW}Missing: ${MISSING_STR:0:45}...${RESET}"
    auto_fix_mark "packages"
fi

# Container package check (Mandatory to have at least one)
if pacman -Qq docker >/dev/null 2>&1 || pacman -Qq podman >/dev/null 2>&1; then
    check "Container Runtime" "Docker/Podman" "true"
else
    check "Container Runtime" "Docker/Podman" "false" "Install docker or podman"
fi

# ── 2. DESKTOP FOUNDATION ────────────────────────────────────────────────────
header "Desktop Foundation"
check "Display Manager" "GDM" "pacman -Qq gdm" || auto_fix_mark "desktop"
check "Network" "NetworkManager" "systemctl is-active NetworkManager" || auto_fix_mark "desktop"
check "Fonts" "noto-fonts" "pacman -Qq noto-fonts" || auto_fix_mark "desktop"
check "Firmware Updates" "fwupd" "pacman -Qq fwupd" || auto_fix_mark "desktop"
check "CPU Microcode" "intel-ucode" "pacman -Qq intel-ucode" || auto_fix_mark "desktop"
check "SSD TRIM Timer" "fstrim.timer" "systemctl is-enabled fstrim.timer" || auto_fix_mark "desktop"
check "Bluetooth" "bluetooth.service" "systemctl is-enabled bluetooth" || auto_fix_mark "desktop"

# ── 3. SERVICES ──────────────────────────────────────────────────────────────
header "Service Verification"
check "Thermal Control" "mbpfan" "systemctl is-active mbpfan" || auto_fix_mark "thermal"

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

# ── 4. OPTIMISATION ──────────────────────────────────────────────────────────
header "Hardware Optimisation"
check "T2 Driver" "apple-bce" "lsmod | grep -q apple_bce"
check "SSD Health" "NVMe TRIM" "findmnt -no OPTIONS / | grep -q 'discard=async'"
check "Thermal Curve" "/etc/mbpfan.conf" "[ -f /etc/mbpfan.conf ]" || auto_fix_mark "thermal"
check "System Performance" "Sysctl Tweaks" "[ -f /etc/sysctl.d/99-macbook-air-2020.conf ]" || auto_fix_mark "optimise"
check "Power Profile" "TLP Config" "[ -f /etc/tlp.d/10-macbook-air-2020.conf ]" || auto_fix_mark "optimise"

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

check "Sleep Mode" "Deep Sleep" "grep -q '\[deep\]' /sys/power/mem_sleep" || auto_fix_mark "optimise"
check "GPU Offload" "i915 GUC/HUC" "[ -f /etc/modprobe.d/i915.conf ]" || auto_fix_mark "optimise"
check "Clock Sync" "RTC UTC" "timedatectl show --property=LocalRTC --value 2>/dev/null | grep -q no" || auto_fix_mark "optimise"

# ── 5. FIRMWARE & STORAGE ────────────────────────────────────────────────────
header "Firmware & Storage"
check "Wi-Fi Driver" "BCM4377b" "[ -f /lib/firmware/brcm/brcmfmac4377b3-pcie.apple,fiji.bin ]"
check "Interface" "wlan0" "ip link show wlan0"
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

check "Vault Mounting" "\$HOME/Code" "findmnt -rno TARGET '$REAL_HOME/Code' || findmnt -rno TARGET /root/Code" || auto_fix_mark "vault"

# ── 6. DEVELOPER ENVIRONMENT ─────────────────────────────────────────────────
header "Developer Environment"
check "Git Signing Key" "user.signingkey" "git config --get user.signingkey"
check "Git GPG Signing" "commit.gpgsign" "[[ \$(git config --get commit.gpgsign 2>/dev/null) == 'true' ]]"

# ── 7. APPLICATION SUITE ─────────────────────────────────────────────────────
header "Application Suite"
APPS=(google-chrome brave-bin libreoffice-fresh loupe gnome-screenshot vlc ghostty zed extension-manager virt-manager nautilus)
declare -A _INST_APPS
while IFS= read -r p; do
    [[ -n "$p" ]] && _INST_APPS["$p"]=1
done < <(pacman -Qq "${APPS[@]}" 2>/dev/null)

MISSING_APPS=()
for app in "${APPS[@]}"; do
    [[ -z "${_INST_APPS[$app]:-}" ]] && MISSING_APPS+=("$app")
done

if [ ${#MISSING_APPS[@]} -eq 0 ]; then
    printf "  %b %b %b\n" "$CHECK" "${LABEL}Standard Apps${RESET}" "${DIM}(All ${#APPS[@]} apps present)${RESET}"
else
    APP_STR="${MISSING_APPS[*]}"
    printf "  %b %b %b %b\n" "$CROSS" "${LABEL}Standard Apps${RESET}" "${DIM}(${#MISSING_APPS[@]} missing)${RESET}" "${YELLOW}Missing: ${APP_STR:0:45}...${RESET}"
fi

printf "\n%bVerification Complete.%b\n" "$LABEL" "$RESET"

# ── AUTO-FIX ────────────────────────────────────────────────────────────────
if $AUTO_FIX && [ ${#FIX_NEEDED[@]} -gt 0 ]; then
    printf "\n%b--auto-fix: Running fix scripts for %d categories...%b\n\n" "$HEADER" "${#FIX_NEEDED[@]}" "$RESET"
    for category in "${FIX_NEEDED[@]}"; do
        local_cmd="${FIX_SCRIPTS[$category]}"
        printf "  %b Fixing: %s%b\n" "$YELLOW" "$category" "$RESET"
        printf "  %b Command: %s%b\n" "$DIM" "$local_cmd" "$RESET"
        if eval "$local_cmd"; then
            printf "  %b %s fixed successfully%b\n\n" "$CHECK" "$category" "$RESET"
        else
            printf "  %b %s fix failed (exit %d)%b\n\n" "$CROSS" "$category" "$?" "$RESET"
        fi
    done
    printf "%bAuto-fix complete. Re-run %bmake verify%b to confirm.%b\n\n" "$LABEL" "$HEADER" "$LABEL" "$RESET"
elif $AUTO_FIX; then
    printf "%bNo fixes needed — all checks passed.%b\n\n" "$LABEL" "$RESET"
else
    printf "Run %bsudo make install%b to fix any issues, or %b--auto-fix%b for targeted repairs.\n\n" "$HEADER" "$RESET" "$HEADER" "$RESET"
fi

exit 0
