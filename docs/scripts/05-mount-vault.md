---
description: 05-mount-vault.sh unlocks and mounts the LUKS2 encrypted code vault from ~/.vault.img to ~/Code.
---

# 05-mount-vault.sh

Unlocks and mounts the LUKS2 encrypted code vault. Opens `~/.vault.img` via `cryptsetup` and mounts it at `~/Code`.

## Usage

```bash
bash scripts/05-mount-vault.sh
```

You will be prompted for your LUKS passphrase via `sudo cryptsetup open`.

## What It Does

1. **Check if already mounted** — if `~/Code` is already a mount point (detected via `findmnt`), exits cleanly with a success message
2. **Verify vault image** — confirms `~/.vault.img` exists; errors if not found
3. **Open LUKS container** — runs `cryptsetup open` if `/dev/mapper/code_vault` does not already exist
4. **Mount** — mounts the decrypted device at `~/Code`
5. **Set ownership** — runs `chown` on the mount point (not recursive)

## Idempotent Behaviour

The script is safe to run multiple times. If the vault is already mounted, it exits immediately without error. If the LUKS container is already open but not mounted, it skips the `cryptsetup open` step and proceeds to mount.

## Files Modified

| Path | Purpose |
|---|---|
| `~/Code` | Mount point (created if missing) |
| `/dev/mapper/code_vault` | LUKS device mapper entry (opened) |

## Prerequisites

- `~/.vault.img` must exist (created by `00-setup-vault.sh`)
- `cryptsetup` installed
- `sudo` access for `cryptsetup open`, `mount`, and `chown`

::: tip Source
View the full source on [GitHub](https://github.com/sebastienrousseau/cachyos-macbook-intel-2020/blob/main/scripts/05-mount-vault.sh).
:::
