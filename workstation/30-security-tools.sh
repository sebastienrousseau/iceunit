#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== Security Tooling Setup ==="

sudo pacman -Sy --needed --noconfirm gitleaks age sops openssh gnupg ufw

# Enable firewall
sudo systemctl enable --now ufw || true
sudo ufw default deny incoming || true
sudo ufw default allow outgoing || true

echo "Security tooling configured."
