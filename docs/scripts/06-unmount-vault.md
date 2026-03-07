---
description: 06-unmount-vault.sh unmounts and locks the LUKS2 encrypted code vault, closing the cryptsetup container.
---

# 06-unmount-vault.sh

Unmounts and locks the LUKS2 encrypted code vault. Unmounts `~/Code` and closes the `cryptsetup` container.

## Usage

```bash
bash scripts/06-unmount-vault.sh [--dry-run] [--help]
```

| Flag | Description |
|---|---|
| `--dry-run` | Preview all actions without modifying the system |
| `--help` | Show usage information and exit |

## What It Does

1. **Unmount** — if `~/Code` is a mount point (detected via `findmnt`), unmounts it
2. **Close LUKS container** — if `/dev/mapper/code_vault` exists, closes it via `cryptsetup close`

## Busy Device Handling

If `umount` fails (typically because a terminal or process has its working directory inside `~/Code`), the script exits with an error message. To resolve:

1. Close any terminals or applications using files inside `~/Code`
2. Run `lsof +D ~/Code` to identify remaining processes
3. Re-run the script

## Idempotent Behaviour

Safe to run multiple times. If the vault is not mounted, the unmount step is skipped. If the LUKS container is already closed, the script reports success.

## Files Modified

| Path | Purpose |
|---|---|
| `~/Code` | Unmounted |
| `/dev/mapper/code_vault` | LUKS device mapper entry (closed) |

## Prerequisites

- `cryptsetup` installed
- `sudo` access for `umount` and `cryptsetup close`

::: tip Source
View the full source on [GitHub](https://github.com/sebastienrousseau/cachyos-macbook-intel-2020/blob/main/scripts/06-unmount-vault.sh).
:::
