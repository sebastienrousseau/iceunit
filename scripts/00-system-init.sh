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

# ── MIRROR RANKING ───────────────────────────────────────────────────────────
# Rank mirrors before installation for faster downloads
if command -v cachyos-rate-mirrors &>/dev/null; then
    printf '\033[0;36m[INFO]\033[0m Ranking mirrors via cachyos-rate-mirrors...\n'
    dryrun cachyos-rate-mirrors
    printf '\033[0;32m[OK]\033[0m Mirrors ranked.\n'
elif command -v rate-mirrors &>/dev/null; then
    printf '\033[0;36m[INFO]\033[0m Ranking mirrors via rate-mirrors...\n'
    dryrun bash -c 'rate-mirrors --protocol https arch | sudo tee /etc/pacman.d/mirrorlist > /dev/null'
    printf '\033[0;32m[OK]\033[0m Mirrors ranked.\n'
elif command -v reflector &>/dev/null; then
    printf '\033[0;36m[INFO]\033[0m Ranking mirrors via reflector...\n'
    dryrun reflector --latest 10 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
    printf '\033[0;32m[OK]\033[0m Mirrors ranked.\n'
else
    printf '\033[1;33m[WARN]\033[0m No mirror ranker found. Install cachyos-rate-mirrors, rate-mirrors, or reflector for faster updates.\n'
fi

# ── INSTALLATION ──────────────────────────────────────────────────────────────
printf '\033[0;36m[INFO]\033[0m Missing %d packages. Synchronising...\n' "${#MISSING_PKGS[@]}"

# Fix ollama conflict: remove untracked /usr/share/ollama if it exists
if [[ " ${MISSING_PKGS[*]} " =~ " ollama " ]] && [ -d "/usr/share/ollama" ] && ! pacman -Qo /usr/share/ollama >/dev/null 2>&1; then
    dryrun sudo rm -rf /usr/share/ollama
fi

dryrun sudo pacman -Sy --needed --noconfirm --overwrite '/usr/share/ollama/*' "${MISSING_PKGS[@]}"
printf '\033[0;32m[OK]\033[0m System initialization complete.\n'
