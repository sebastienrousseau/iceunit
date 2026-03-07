# Wi-Fi Firmware

The Broadcom BCM4377b requires proprietary firmware files that cannot be bundled with the kernel or redistributed. They must be sourced from macOS or from the arch-mact2 community mirror.

## Firmware Files Required

The MacBook Air 2020 uses board ID **fiji**. The following files must be present in `/lib/firmware/brcm/`:

| File | Purpose |
|---|---|
| `brcmfmac4377b3-pcie.apple,fiji.bin` | Main Wi-Fi firmware |
| `brcmfmac4377b3-pcie.apple,fiji.clm_blob` | Channel/regulatory data |
| `brcmfmac4377b3-pcie.apple,fiji.txcap_blob` | Transmit calibration |
| `brcmbt4377b3-apple,formosa.bin` | Bluetooth firmware |

## Option 1 — Install via Package (Recommended)

The `arch-mact2` mirror provides a `apple-bcm-firmware` package that contains firmware for all supported Apple Macs:

```bash
# The script handles this automatically
bash scripts/02-wifi-firmware.sh install-pkg
```

Or manually:
```bash
# Add the t2linux repo to /etc/pacman.conf first, then:
sudo pacman -Sy apple-bcm-firmware
```

## Option 2 — Extract from macOS

If you have access to a macOS partition (or Time Machine backup):

```bash
# macOS firmware location
/usr/share/firmware/wifi/

# Copy the relevant files
sudo cp /Volumes/Macintosh\ HD/usr/share/firmware/wifi/C-4377__s-B3/*.bin \
    /lib/firmware/brcm/

# Reload firmware
sudo modprobe -r brcmfmac && sudo modprobe brcmfmac
```

## Verifying Firmware is Loaded

```bash
# Check Wi-Fi device is recognised
ip link show | grep wlan

# Check for firmware errors in kernel log
sudo dmesg | grep -i brcmfmac | tail -20

# List Wi-Fi networks
nmcli device wifi list
```

Expected kernel log output (no errors):
```
brcmfmac: brcmf_fw_alloc_request: using brcm/brcmfmac4377b3-pcie.apple,fiji
brcmfmac 0000:01:00.0: Direct firmware load for brcm/... succeeded
```

## Backup and Restore

The `02-wifi-firmware.sh` script supports backup and restore to preserve your firmware across reinstalls:

```bash
# Backup current firmware to ~/wifi-firmware-backup/
bash scripts/02-wifi-firmware.sh backup

# Restore from backup
bash scripts/02-wifi-firmware.sh restore
```
