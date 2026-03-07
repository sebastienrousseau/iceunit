---
description: Step-by-step CachyOS installation on the MacBook Air 2020 using Calamares with dual-boot macOS partition guidance.
---

# Running the Installer

## CachyOS Hello / Calamares

Boot from the USB, open the **CachyOS Hello** app, and click **Install System**. This launches the Calamares graphical installer.

Work through the steps:

1. **Location** — timezone and locale
2. **Keyboard** — layout (the MacBook keyboard is detected automatically via `apple_bce`)
3. **Partitions** — see below
4. **Users** — create your user account; keep the username lowercase with no spaces
5. **Summary** — review and click **Install**

## Partitions Screen

Choose **Manual partitioning** if you want dual-boot with macOS. Select your existing EFI partition (`nvme0n1p1`) and set:
- Mount point: `/boot`
- **Do not format** — this preserves macOS boot files

Create or select the remaining space for the root partition with BTRFS.

::: warning Do not format the EFI partition
The EFI partition contains macOS bootloader files. Formatting it will prevent macOS from booting. Set the mount point only, not the format flag.
:::

## Kernel Selection

During the CachyOS install, select the **linux-cachyos** kernel (BORE scheduler). This is the kernel all scripts and this guide are tested against.

## First Boot

After install, the system boots into Limine. Select **CachyOS** from the boot menu.

The first thing to do after logging in:

```bash
# Update the system
sudo pacman -Syu

# Install Go (required for the new installer)
sudo pacman -S go

# Clone the scripts repo
git clone https://github.com/sebastienrousseau/cachyos-macbook-intel-2020.git
cd cachyos-macbook-intel-2020

# Run the interactive Iceunit (ICU) installer for automated setup
make install

# Finally, verify your system health
make verify
```
