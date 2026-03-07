---
description: Overview of CachyOS on the MacBook Air 2020 with field-tested solutions for thermal, Wi-Fi firmware, fish shell, and apple_bce issues.
---

# Introduction

This guide documents a complete, field-tested installation and optimisation of [CachyOS](https://cachyos.org) on a **2020 Intel MacBook Air (MacBookAir9,1)**. Every configuration detail has been verified on a live running system.

## What is CachyOS?

CachyOS is an Arch Linux-based distribution built for performance. It ships with optimised kernels (BORE scheduler, LTO compilation, x86-64-v3 instruction sets), sensible defaults, and — since June 2024 — **official T2 MacBook support** built directly into the default kernel.

For Intel Macs reaching end-of-life from Apple's update support, CachyOS is an excellent way to keep your hardware fast, secure, and useful for years to come.

## Why This Guide?

The official CachyOS wiki covers T2 Macs generally. This guide is specific to the **MacBook Air 2020 (MacBookAir9,1)** and documents real-world issues you'll encounter that aren't covered elsewhere:

- The fan exposes itself via ACPI (`APP0001:00`), not the traditional `applesmc` platform path — this breaks the default `thermald` configuration
- `apple_bce` is compiled into the CachyOS kernel (not a loadable module), so `modprobe apple-bce` always fails
- Glob patterns in scripts fail silently when called from **fish shell** via `sudo bash`
- `paru`/`yay` cannot be called via `sudo -u` inside a sudo session

All of these are fixed in this guide's scripts.

## System Overview

| Component | Detail |
|---|---|
| **Model** | Apple MacBook Air 2020 (MacBookAir9,1) |
| **CPU** | Intel Core i5-1030NG7 @ 1.10GHz (Ice Lake) |
| **Kernel** | 6.19.x-cachyos |
| **Bootloader** | Limine 10.8.2 |
| **Audio** | PipeWire 1.6.0 via apple-bce |
| **Swap** | ZRAM 15.4G (zstd) |

## Quick Start

If you're already running CachyOS, start here:

::: warning Run thermal setup first
Your CPU can sustain 100°C at near-idle fan speeds without intervention. This is the first thing to fix.
:::

```bash
# Run the unified interactive Bubble Tea installer (requires Go)
make install
```

For a fresh install, start with [Disable T2 Security](/guide/disable-t2-security).
