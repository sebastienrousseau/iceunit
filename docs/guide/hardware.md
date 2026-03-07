---
description: Hardware specifications for the MacBook Air 2020 including Intel Ice Lake CPU, Apple T2 chip, BCM4377b Wi-Fi, and ACPI fan path.
---

# Hardware Specifications

## Target Hardware

| Component | Specification | Driver / Module |
|---|---|---|
| **Model** | Apple MacBook Air 2020 (MacBookAir9,1) | — |
| **CPU** | Intel Core i5-1030NG7 @ 1.10GHz (Ice Lake) | `intel_idle`, `intel_pstate` |
| **Graphics** | Intel Iris Plus Graphics G7 (Ice Lake) | `i915` |
| **Security / Audio** | Apple T2 Bridge & Secure Enclave | `apple_bce` |
| **Wi-Fi** | Broadcom BCM4377b | `brcmfmac` |
| **Bluetooth** | Broadcom BRCM4377 | `hci_bcm4377` |
| **Storage** | Apple NVMe (nvme0n1) | `nvme` |
| **Bootloader** | Limine 10.8.2 | `limine-entry-tool` |
| **Audio** | Apple T2 Audio via apple-bce | PipeWire 1.6.0 |
| **Swap** | ZRAM 15.4G (zstd) | `zram-generator` |

## Key Hardware Notes

### Apple T2 Chip

The T2 is a custom ARM-based security chip that sits between Linux and several hardware components including:

- **Keyboard and trackpad** — communicated over a PCIe-to-USB bridge (`apple_bce`)
- **Audio** — T2 acts as an audio DSP; the `apple-bce` driver exposes it as a standard ALSA device
- **Storage** — the NVMe controller is behind the T2; works transparently once booted
- **Touch ID** — not supported on Linux; the Secure Enclave cannot be accessed

### Fan / Thermal Path

Unlike older MacBooks, the fan on the MacBook Air 2020 running kernel 6.19.x-cachyos is exposed via the **ACPI `APP0001:00` device**, not the traditional `applesmc` platform driver:

```
/sys/devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A08:00/device:1c/APP0001:00/
├── fan1_output   ← current fan speed (RPM)
├── fan1_min      ← minimum fan speed (2700 RPM)
└── fan1_max      ← maximum fan speed (8000 RPM)
```

This is why `thermald` alone doesn't control the fan correctly — it expects the `applesmc` path. The [Thermal Setup](/guide/thermal-setup) guide covers this in detail.

### apple_bce Module

`apple_bce` is compiled **directly into** the CachyOS kernel (`CONFIG_APPLE_BCE=y`), not as a loadable module. This means:

- `modprobe apple-bce` will always fail with "module not found"
- `lsmod | grep apple_bce` will show it as active (it's always loaded)
- Keyboard, trackpad, and audio work from first boot without any extra steps

### Wi-Fi Firmware

The Broadcom BCM4377b requires proprietary firmware that **cannot be redistributed**. It must be extracted from macOS or downloaded from the arch-mact2 mirror. See [Wi-Fi Firmware](/guide/wifi-firmware).

Firmware files for this hardware (board ID: **fiji**):
- `brcmfmac4377b3-pcie.apple,fiji.bin`
- `brcmfmac4377b3-pcie.apple,fiji.clm_blob`
- `brcmfmac4377b3-pcie.apple,fiji.txcap_blob`
- `brcmbt4377b3-apple,formosa.bin` (Bluetooth)
