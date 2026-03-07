# Changelog

## v1.0.0 — March 2026

Initial public release. All scripts field-tested on MacBook Air 2020 (MacBookAir9,1) running CachyOS kernel 6.19.x.

### Added
- `00-setup-vault.sh` — first-time LUKS2 encrypted vault setup with interactive size selection
- `01-thermal-setup.sh` — mbpfan installation and fan curve configuration for APP0001:00 ACPI path
- `02-wifi-firmware.sh` — BCM4377b firmware verify, backup, restore, and re-install
- `03-optimise.sh` — Ice Lake kernel params, TLP drop-in, PipeWire T2 audio config, suspend fix service
- `04-bootloader.sh` — Limine management, optional rEFInd install, EFI boot order management
- `05-mount-vault.sh` — unlock and mount LUKS2 code vault
- `06-unmount-vault.sh` — lock and unmount LUKS2 code vault
- VitePress documentation site

### Fixed
- Replaced all glob patterns (`applesmc.*`) with `find` commands for fish shell compatibility
- Removed `sudo -u` AUR helper calls (paru/yay hang when called via sudo -u inside sudo session)
- Fan sysfs path now detected dynamically via ACPI path instead of hardcoded `applesmc.768`
- mbpfan config uses `coretemp` sensors only (applesmc TC* sensors not available via expected path on 6.19.x)

### Known Issues
- Webcam support varies by kernel version — check T2 Linux roadmap
- Thunderbolt-specific features limited
