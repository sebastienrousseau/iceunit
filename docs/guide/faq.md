# FAQ

## Can I use this guide on a different MacBook model?

Partially. The scripts detect your hardware dynamically, but the thermal configuration and firmware board IDs are specific to the MacBook Air 2020 (MacBookAir9,1). For other models:

- Fan paths may differ
- Wi-Fi board ID will be different — run `02-wifi-firmware.sh` with your correct board ID
- Refer to [t2linux.org](https://t2linux.org) for model-specific guidance

## Does Touch ID work?

No. The Secure Enclave in the T2 chip cannot be accessed from Linux. Touch ID is not supported and is not expected to be supported in the future.

## Can I dual-boot with macOS?

Yes. The guide covers this setup. macOS and CachyOS coexist on the same EFI partition. You can switch between them with `efibootmgr` or by holding **Option (⌥)** at startup.

## Will updates break my setup?

The riskiest updates are kernel updates — a bad kernel can prevent boot. Mitigations:
- `limine-snapper-sync` creates a boot entry for every BTRFS snapshot
- If a kernel update breaks boot, hold Space at Limine to access the snapshot menu and boot the previous working snapshot

## Why CachyOS and not plain Arch?

CachyOS ships with:
- The BORE (Burst-Oriented Response Enhancer) CPU scheduler — measurably lower input latency
- LTO-compiled packages for the base system
- x86-64-v3 instruction set optimisations for Ice Lake
- T2 Mac support included in the default kernel without manual patching

For a MacBook, the T2 support in the CachyOS kernel is the most important reason.

## Can I use a different AUR helper?

Yes. Both `paru` and `yay` are supported. The scripts detect whichever is installed. If both are installed, `paru` takes precedence.

## How do I update the site documentation?

Edit any `.md` file in the `docs/` directory and push to `main`. GitHub Actions will rebuild and deploy the site automatically within ~2 minutes.

To preview changes locally:
```bash
npm install
npm run docs:dev
```
