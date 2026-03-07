---
description: Complete guide to installing and optimising CachyOS on the 2020 Intel MacBook Air with T2 chip. Thermal fixes, Wi-Fi firmware, encrypted vault, and Limine bootloader.
layout: home

hero:
  name: "CachyOS"
  text: "on MacBook Air 2020"
  tagline: Complete guide to installing and optimising CachyOS on the Intel MacBook Air (MacBookAir9,1) with T2 chip support. Field-tested, production-ready.
  image:
    src: /hero-macbook.svg
    alt: MacBook Air with CachyOS
  actions:
    - theme: brand
      text: Get Started
      link: /guide/introduction
    - theme: alt
      text: View Scripts
      link: /scripts/overview
    - theme: alt
      text: GitHub
      link: https://github.com/sebastienrousseau/cachyos-macbook-intel-2020

features:
  - icon: 🌡️
    title: Thermal Fixed
    details: mbpfan configured with correct Apple SMC sensor paths. Fan ramps from 2700 to 8000 RPM based on real temperatures — no more 100°C at idle.

  - icon: 📡
    title: Wi-Fi & Bluetooth
    details: Broadcom BCM4377b firmware extracted and verified. Both brcmfmac and hci_bcm4377 working out of the box with backup and restore scripts.

  - icon: 🔐
    title: Encrypted Vault
    details: LUKS2-encrypted BTRFS loopback container for source code. Simple mount/unmount scripts for daily use, fully documented setup for new users.

  - icon: 🥾
    title: Limine Bootloader
    details: Limine 10.8.2 with limine-snapper-sync. Boot from any of your BTRFS snapshots directly from the boot menu. rEFInd optional dual-boot support.

  - icon: ⚡
    title: Ice Lake Optimised
    details: Kernel parameters, TLP power profiles, and PipeWire audio tuned specifically for the Intel Core i5-1030NG7 and Apple T2 BCE bridge.

  - icon: 🐚
    title: Fish Shell Compatible
    details: All scripts use find instead of globs — tested and working from fish, bash, and zsh. No surprises when running from your preferred shell.
---
