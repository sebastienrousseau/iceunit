# 00-setup-vault.sh

First-time creation of a LUKS2-encrypted BTRFS loopback container for securing source code and secrets. The vault lives at `~/.vault.img` and mounts at `~/Code`. Run this script **once** on a fresh install.

## Usage

```bash
bash scripts/00-setup-vault.sh
```

The script is interactive — it prompts for vault size and LUKS passphrase.

## What It Does

1. **Preflight checks** — verifies `cryptsetup` and `btrfs-progs` are installed, confirms no existing vault image or mount
2. **Size selection** — displays available disk space and prompts for vault size (default: 60 GB)
3. **Image creation** — allocates a fixed-size file via `fallocate` (falls back to `dd`)
4. **LUKS2 encryption** — formats the image with `aes-xts-plain64`, 512-bit key, SHA-512 hash, Argon2id KDF
5. **BTRFS formatting** — creates a BTRFS filesystem labelled `CODE_REPOS` inside the encrypted container
6. **Mount and own** — mounts at `~/Code` and sets ownership to the current user
7. **Verification** — confirms the mount succeeded and displays LUKS container details

## LUKS2 Parameters

| Parameter | Value |
|---|---|
| Type | LUKS2 |
| Cipher | `aes-xts-plain64` |
| Key size | 512 bits |
| Hash | SHA-512 |
| KDF | Argon2id |

## Files Modified

| Path | Purpose |
|---|---|
| `~/.vault.img` | Encrypted container image (created) |
| `~/Code` | Mount point directory (created) |

## Prerequisites

- `cryptsetup` — `sudo pacman -S cryptsetup`
- `btrfs-progs` — `sudo pacman -S btrfs-progs`
- Sufficient disk space for the chosen vault size

## Input Validation

- Size must match `[1-9][0-9]*[GgMm]` — values like `0G` are rejected
- Mount detection uses `findmnt` instead of parsing `mount` output

::: tip Source
View the full source on [GitHub](https://github.com/sebastienrousseau/cachyos-macbook-intel-2020/blob/main/scripts/00-setup-vault.sh).
:::
