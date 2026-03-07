#!/bin/bash
# Strict mode: exit on error, undefined variables, or pipe failures
set -euo pipefail

# Configuration
MAPPER_NAME="my_encrypted_vault"
MOUNT_POINT="$HOME/CodeVault"

echo "🔒 Securing and unmounting the code vault..."

# 1. Unmount the directory if it's currently mounted
if mount | grep -q "$MOUNT_POINT"; then
    echo "Unmounting $MOUNT_POINT..."
    sudo umount "$MOUNT_POINT"
else
    echo "ℹ️ Vault is not currently mounted."
fi

# 2. Close the LUKS container if it's currently open
if [ -e "/dev/mapper/$MAPPER_NAME" ]; then
    echo "Closing encrypted container..."
    sudo cryptsetup close "$MAPPER_NAME"
    echo "✅ Vault successfully locked and secured."
else
    echo "✅ Vault is already locked."
fi
