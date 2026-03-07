#!/bin/bash
set -euo pipefail

MAPPER_NAME="code_vault"
MOUNT_POINT="$HOME/Code"
VAULT_IMG="$HOME/.vault.img"

echo "🔐 Unlocking and mounting the code vault..."

if mount | grep -q "$MOUNT_POINT"; then
    echo "✅ Vault is already mounted at $MOUNT_POINT"
    exit 0
fi

if [ ! -e "/dev/mapper/$MAPPER_NAME" ]; then
    sudo cryptsetup open "$VAULT_IMG" "$MAPPER_NAME"
fi

sudo mount "/dev/mapper/$MAPPER_NAME" "$MOUNT_POINT"
sudo chown -R "$USER:$USER" "$MOUNT_POINT"
echo "✅ Vault successfully mounted at $MOUNT_POINT"
