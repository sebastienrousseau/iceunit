#!/bin/bash
set -euo pipefail

MAPPER_NAME="code_vault"
MOUNT_POINT="$HOME/Code"

echo "🔒 Securing and unmounting the code vault..."

if mount | grep -q "$MOUNT_POINT"; then
    echo "Unmounting $MOUNT_POINT..."
    sudo umount "$MOUNT_POINT"
else
    echo "ℹ️ Vault is not currently mounted."
fi

if [ -e "/dev/mapper/$MAPPER_NAME" ]; then
    echo "Closing encrypted container..."
    sudo cryptsetup close "$MAPPER_NAME"
    echo "✅ Vault successfully locked and secured."
else
    echo "✅ Vault is already locked."
fi
