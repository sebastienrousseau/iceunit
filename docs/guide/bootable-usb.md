---
description: Create a bootable CachyOS USB and boot the MacBook Air 2020 from external media using the Option key.
verifiedOn: 2026-04-01
---

# Create Bootable USB

## Download CachyOS

Download the latest ISO from the [CachyOS website](https://cachyos.org/download/).

Verify the checksum before writing:

```bash
sha256sum cachyos-*.iso
# Compare against the .sha256 file on the download page
```

## Write the ISO

### On Linux / macOS

```bash
# Find your USB drive device
lsblk   # Linux
diskutil list   # macOS

# Write (replace /dev/sdX or /dev/diskN with your device)
sudo dd if=cachyos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

::: danger Double-check the target device
`dd` will overwrite anything at the target path without confirmation. Verify the device name with `lsblk` before running.
:::

### On Windows

Use [Rufus](https://rufus.ie/) with:
- Partition scheme: **GPT**
- Target system: **UEFI (non CSM)**
- Write mode: **DD Image**

## Boot from USB

1. Insert the USB drive
2. Power on while holding **Option (⌥)**
3. Select the **EFI Boot** entry (yellow icon, typically labelled "EFI Boot")
4. CachyOS live environment will start

::: tip If no EFI Boot option appears
Ensure Startup Security Utility is set to "No Security" and external media is allowed. See [Disable T2 Security](/guide/disable-t2-security).
:::
