#!/usr/bin/env bash
set -Eeuo pipefail

DRY_RUN=false
ASSUME_YES=false
for arg in "$@"; do
    [[ "$arg" == "--dry-run" ]] && DRY_RUN=true
    # shellcheck disable=SC2034
    [[ "$arg" == "--yes" ]] && ASSUME_YES=true
done

# Wrapper for destructive commands
dryrun() {
    if $DRY_RUN; then
        printf '\033[1;30m[DRY-RUN]\033[0m %s\n' "$*"
    else
        "$@"
    fi
}

log()   { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }

log "=== GNOME Productivity Setup ==="

if ! command -v gsettings >/dev/null 2>&1; then
  log "GNOME not detected, skipping."
  exit 0
fi

# Faster UI
dryrun gsettings set org.gnome.desktop.interface enable-animations false || true

# Focus follows mouse (optional productivity preference)
dryrun gsettings set org.gnome.desktop.wm.preferences focus-mode 'sloppy' || true

# Workspace shortcuts
dryrun gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Super>1']"
dryrun gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Super>2']"
dryrun gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Super>3']"

# Launch terminal with Super+Return
dryrun gsettings set org.gnome.settings-daemon.plugins.media-keys terminal "['<Super>Return']" || true

log "GNOME productivity configuration applied."
