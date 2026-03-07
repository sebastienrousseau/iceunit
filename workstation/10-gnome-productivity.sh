#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== GNOME Productivity Setup ==="

if ! command -v gsettings >/dev/null 2>&1; then
  echo "GNOME not detected, skipping."
  exit 0
fi

# Faster UI
gsettings set org.gnome.desktop.interface enable-animations false || true

# Focus follows mouse (optional productivity preference)
gsettings set org.gnome.desktop.wm.preferences focus-mode 'sloppy' || true

# Workspace shortcuts
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-1 "['<Super>1']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-2 "['<Super>2']"
gsettings set org.gnome.desktop.wm.keybindings switch-to-workspace-3 "['<Super>3']"

# Launch terminal with Super+Return
gsettings set org.gnome.settings-daemon.plugins.media-keys terminal "['<Super>Return']" || true

echo "GNOME productivity configuration applied."
