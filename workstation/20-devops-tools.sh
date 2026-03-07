#!/usr/bin/env bash
set -Eeuo pipefail

echo "=== DevOps Tooling Setup ==="

sudo pacman -Sy --needed --noconfirm kubectl helm k9s terraform ansible stern dive rsync

# Install kubectl completion
if command -v kubectl >/dev/null 2>&1; then
  kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl >/dev/null || true
fi

echo "DevOps tooling installed."
