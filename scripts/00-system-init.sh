#!/usr/bin/env bash
set -Eeuo pipefail

DRY_RUN=false
ASSUME_YES=false
for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
    # shellcheck disable=SC2034
    [[ "$arg" == "--yes" ]] && ASSUME_YES=true
    [[ "$arg" == "--help" || "$arg" == "-h" ]] && {
        echo "Usage: sudo bash $0 [--dry-run] [--yes] [--help]"
        echo "Install all Iceunit core packages via pacman."
        exit 0
    }
done

# Wrapper for destructive commands
dryrun() {
    if $DRY_RUN; then
        printf '\033[1;30m[DRY-RUN]\033[0m %s\n' "$*"
    else
        "$@"
    fi
}

PKGS=(
    bc lm_sensors htop btop nvme-cli smartmontools powertop cpupower tlp pipewire pipewire-pulse wireplumber limine efibootmgr refind snapper btrfs-progs cryptsetup git curl wget base-devel ripgrep fd fzf bat eza jq yq neovim tmux zoxide atuin direnv starship podman podman-compose python python-pip python-pipx nodejs npm go rust cmake ninja gcc clang mold lazygit github-cli ollama kubectl helm k9s terraform ansible stern dive rsync gitleaks age sops openssh gnupg ufw
)

# ── SMART CHECK ──────────────────────────────────────────────────────────────
# Identify which packages are actually missing
MISSING_PKGS=()
for pkg in "${PKGS[@]}"; do
    if ! pacman -Qq "$pkg" >/dev/null 2>&1; then
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -eq 0 ]; then
    printf '\033[0;32m[OK]\033[0m All Iceunit packages are already installed. Skipping initialization.\n'
    exit 0
fi

# ── INSTALLATION ──────────────────────────────────────────────────────────────
printf '\033[0;36m[INFO]\033[0m Missing %d packages. Synchronising...\n' "${#MISSING_PKGS[@]}"

# Fix ollama conflict: remove untracked /usr/share/ollama if it exists
if [[ " ${MISSING_PKGS[*]} " =~ " ollama " ]] && [ -d "/usr/share/ollama" ] && ! pacman -Qo /usr/share/ollama >/dev/null 2>&1; then
    dryrun sudo rm -rf /usr/share/ollama
fi

dryrun sudo pacman -Sy --needed --noconfirm --overwrite '/usr/share/ollama/*' "${MISSING_PKGS[@]}"
printf '\033[0;32m[OK]\033[0m System initialization complete.\n'
