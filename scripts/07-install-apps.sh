#!/usr/bin/env bash
# =============================================================================
# 07-install-apps.sh
# Standard application suite for Iceunit (ICU) on CachyOS.
# =============================================================================

set -Eeuo pipefail

DRY_RUN=false
ASSUME_YES=false
for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
    # shellcheck disable=SC2034
    [[ "$arg" == "--yes" ]] && ASSUME_YES=true
    [[ "$arg" == "--help" || "$arg" == "-h" ]] && {
        echo "Usage: bash $0 [--dry-run] [--yes] [--help]"
        echo "Install the standard Iceunit application suite."
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

# Logging helpers
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*"; exit 1; }

# Define standard app suite
APPS=(
    "google-chrome"
    "brave-bin"
    "libreoffice-fresh"
    "loupe"
    "gnome-screenshot"
    "vlc"
    "ghostty"
    "zed"
    "extension-manager"
    "virt-manager"
    "nautilus"
)

# Identify which packages are actually missing
MISSING_APPS=()
for app in "${APPS[@]}"; do
    if ! pacman -Qq "$app" >/dev/null 2>&1; then
        MISSING_APPS+=("$app")
    fi
done

if [ ${#MISSING_APPS[@]} -eq 0 ]; then
    success "All standard applications are already installed."
    exit 0
fi

info "Missing ${#MISSING_APPS[@]} applications. Synchronizing..."

# Detect AUR helper (paru is default on CachyOS)
HELPER="pacman"
if command -v paru >/dev/null 2>&1; then
    HELPER="paru"
elif command -v yay >/dev/null 2>&1; then
    HELPER="yay"
fi

if [[ "$HELPER" == "pacman" ]]; then
    dryrun sudo pacman -S --needed --noconfirm "${MISSING_APPS[@]}"
else
    # AUR helpers should not be run as root
    if [[ $EUID -eq 0 ]]; then
        REAL_USER="${SUDO_USER:-${USER}}"
        dryrun sudo -u "$REAL_USER" "$HELPER" -S --needed --noconfirm "${MISSING_APPS[@]}"
    else
        dryrun "$HELPER" -S --needed --noconfirm "${MISSING_APPS[@]}"
    fi
fi

success "Application Suite synchronisation complete."
