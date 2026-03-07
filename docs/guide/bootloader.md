---
description: Configure Limine with limine-snapper-sync for BTRFS snapshot booting and optional rEFInd dual-boot on the MacBook Air 2020.
---

# Bootloader: Limine

## Overview

The reference system uses **Limine 10.8.2** as the primary bootloader. Limine is installed to the EFI System Partition at `/boot/EFI/limine/`, and its entry is registered with the system firmware.

```
EFI boot order (efibootmgr output)
BootCurrent: 0001
BootOrder: 0001,0080,0000
Boot0001* Limine
Boot0080* Mac OS X
Boot0000* Zorin OS
```

## limine-snapper-sync

`limine-snapper-sync` hooks into BTRFS snapshots via snapper and updates the Limine menu automatically. Every time `snapper` creates a snapshot, a corresponding boot entry appears in Limine. This means you can **boot any previous snapshot directly from the boot menu** without any manual steps.

Install:
```bash
paru -S limine-snapper-sync
sudo systemctl enable --now limine-snapper-sync.timer
```

## Managing Boot Entries

```bash
# View current boot order
sudo efibootmgr

# Set a specific entry as default (use 4-digit hex number from efibootmgr output)
sudo efibootmgr --bootorder 0001,0080

# Boot macOS on next boot only (without changing default)
sudo efibootmgr -n 0080

# Run the full bootloader management script
sudo bash scripts/04-bootloader.sh
```

## Optional: rEFInd for Dual Boot

If you prefer a graphical boot picker that auto-detects all OS entries, `04-bootloader.sh` can install rEFInd alongside Limine:

```bash
sudo bash scripts/04-bootloader.sh --install-refind
```

rEFInd will scan EFI entries and provide a graphical menu with icons. Limine remains as a fallback.

## Recovering from a Failed Boot

If a kernel update breaks boot:

1. Hold **Space** at the Limine splash — this shows the snapshot menu
2. Select the last known good snapshot
3. Boot into it and then run:

```bash
# Revert the bad kernel from the running good snapshot
sudo snapper rollback <snapshot-number>
sudo reboot
```
