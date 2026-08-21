---
description: Release history and known issues for CachyOS MacBook Air 2020 scripts and configuration.
---

# Changelog

## v0.0.2 — April 2026

### Performance

- Batch `pacman -Qq` queries into a single fork with associative-array lookups (`00-system-init.sh`, `03-optimise.sh`, `99-verify-install.sh`)
- Add 24-hour TTL cache for mirror ranking — skip re-ranking when mirrorlist is fresh (`00-system-init.sh`, `08-maintenance.sh`)
- Replace unbounded `strings.Builder` with fixed-capacity ring buffer (100 lines) in Go installer
- Replace sequential `io.MultiReader` with concurrent stdout/stderr goroutines in Go installer
- Resolve `projectRoot` once at startup instead of per-task in Go installer

### Fixed

- `vm.swappiness` `10` → `133` — correct value for ZRAM (compressed-RAM swap benefits from aggressive swapping)
- `vm.dirty_writeback_centisecs` / `vm.dirty_expire_centisecs` `6000` → `1500` — better responsiveness without excessive NVMe wear
- Removed `autodefrag` from BTRFS mount recommendations — causes write amplification on NVMe with no seek benefit
- Removed `pcie_aspm=off` from kernel cmdline — blanket disable kills 10-15% battery life
- Set TLP `PCIE_ASPM_ON_BAT=powersupersave` — per-device ASPM management by TLP replaces global kernel disable
- Fixed `tests/Dockerfile.unit` — missing `COPY tests/helpers/` and `COPY tests/contracts/` directives

### Docs

- Updated all documentation to reflect changed sysctl values, kernel parameters, BTRFS options, and TLP config
- Updated test count from 230 to 303

---

## v1.1.0 — March 2026

### Added
- `--dry-run` flag on all scripts — preview actions without modifying the system
- `--help` flag on all scripts — display usage information
- 230 unit tests using bats-core with full mock framework (`tests/*.bats`)
- Docker-based unit test container (`tests/Dockerfile.unit`) on Arch Linux
- Docker-based integration test container (`tests/Dockerfile.integration`) on Arch Linux with real packages
- Consolidated CI workflow (`.github/workflows/tests.yml`) with ShellCheck, unit tests, and integration tests
- Unit tests for all 6 workstation scripts (`tests/w*.bats`)
- Expanded integration tests covering workstation dry-run and additional core scripts
- Testing section in README, CONTRIBUTING, and scripts overview docs

### Fixed
- `02-wifi-firmware.sh`: replaced glob patterns in backup/restore with `find` commands for fish shell compatibility
- `03-optimise.sh`: replaced `sudo -u "$SUDO_USER"` with direct `HOME` override to avoid hanging AUR helpers
- `05-mount-vault.sh`: added `$USER` fallback via `whoami` for environments where `$USER` is unset (e.g. Docker containers)
- `tests/integration/run-all.sh`: fixed `((PASS++))` arithmetic causing `set -e` to exit when counter is zero

---

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
