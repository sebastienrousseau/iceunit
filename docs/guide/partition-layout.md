---
description: Partition layout, BTRFS subvolumes, mount options, and ZRAM swap for CachyOS on the MacBook Air 2020.
---

# Partition Layout

## Recommended Layout

This is the layout used on the reference system (dual-boot with macOS):

| Partition | Size | Filesystem | Mount | Purpose |
|---|---|---|---|---|
| `nvme0n1p1` | 300 MB | FAT32 | `/boot` | EFI System Partition (shared with macOS) |
| `nvme0n1p2` | Remaining | BTRFS | `/` | CachyOS root |

::: info Single macOS EFI partition
The MacBook Air 2020 uses a single EFI partition shared between macOS and Linux bootloaders. Limine installs its EFI binary alongside the Apple one — they coexist safely.
:::

## BTRFS Subvolumes

The CachyOS installer creates the following BTRFS subvolume layout by default:

```
nvme0n1p2 (BTRFS pool)
├── @           → /
├── @home       → /home
├── @pkg        → /var/cache/pacman/pkg
├── @log        → /var/log
└── @snapshots  → /.snapshots
```

## Recommended Mount Options

After install, update `/etc/fstab` BTRFS entries to use these options for better performance on NVMe:

```
UUID=<uuid>  /  btrfs  noatime,compress=zstd:1,space_cache=v2,autodefrag,discard=async,subvol=@  0 0
```

Key options explained:
- `noatime` — don't write file access times (significant NVMe write reduction)
- `compress=zstd:1` — transparent compression, level 1 (fast, good ratio)
- `space_cache=v2` — faster free-space lookup
- `autodefrag` — automatic background defragmentation for small files
- `discard=async` — asynchronous TRIM (much lower latency than `discard=sync`)

## ZRAM Swap

The reference system uses ZRAM instead of a swap partition:

```
/dev/zram0   15.4G   zstd compression
```

No swap partition is needed. ZRAM is configured automatically by `zram-generator`. Verify:

```bash
zramctl
swapon --show
```
