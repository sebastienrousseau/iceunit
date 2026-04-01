---
description: Create and manage a LUKS2-encrypted BTRFS loopback vault for source code on CachyOS MacBook Air 2020.
verifiedOn: 2026-04-01
---

# Encrypted Code Vault

The vault is a LUKS2-encrypted BTRFS loopback image used to store source code and sensitive project files. It lives at `~/.vault.img` and mounts to `~/Code`.

## Creating the Vault (First Time)

```bash
bash scripts/00-setup-vault.sh
```

The script will ask for:
- **Vault size** — default 60G (can be grown later)
- **LUKS2 passphrase** — choose a strong one; this encrypts everything in the vault

What it creates:
```
~/.vault.img          ← encrypted container (BTRFS inside LUKS2)
~/Code/               ← mount point (empty when vault is locked)
```

## Daily Use

```bash
# Unlock and mount
bash [scripts/05-mount-vault.sh](/scripts/05-mount-vault)

# Lock and unmount
bash [scripts/06-unmount-vault.sh](/scripts/06-unmount-vault)
```

## Vault Details

| Property | Value |
|---|---|
| Image path | `~/.vault.img` |
| Mapper name | `code_vault` |
| Mount point | `~/Code` |
| Filesystem | BTRFS |
| Label | `CODE_REPOS` |
| Encryption | LUKS2 (aes-xts-plain64, 512-bit key) |
| Current size | 60G (41% used on reference system) |

## Manual Operations

```bash
# Open the vault manually
sudo cryptsetup open ~/.vault.img code_vault
sudo mount /dev/mapper/code_vault ~/Code
sudo chown $USER:$USER ~/Code

# Close the vault manually
sudo umount ~/Code
sudo cryptsetup close code_vault

# Check vault usage
df -h ~/Code
```

## Growing the Vault

If you run out of space:

```bash
# Close the vault first
bash scripts/06-unmount-vault.sh

# Grow the image by 20G
sudo dd if=/dev/zero bs=1G count=20 >> ~/.vault.img

# Reopen and resize
sudo cryptsetup open ~/.vault.img code_vault
sudo cryptsetup resize code_vault
sudo mount /dev/mapper/code_vault ~/Code
sudo btrfs filesystem resize max ~/Code
```

## Backup

Back up by copying the raw image file. The entire encrypted container is a single file:

```bash
# Close vault before backup
bash scripts/06-unmount-vault.sh

# Backup (rsync preserves sparse files)
rsync -avP --sparse ~/.vault.img /path/to/backup/
```
