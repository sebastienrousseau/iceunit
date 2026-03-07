# CachyOS on MacBook Air 2020 (Intel)

[![Tests](https://github.com/sebastienrousseau/cachyos-macbook-intel-2020/actions/workflows/tests.yml/badge.svg)](https://github.com/sebastienrousseau/cachyos-macbook-intel-2020/actions/workflows/tests.yml)
[![Docs](https://img.shields.io/badge/docs-iceunit.com-blue)](https://iceunit.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-MacBookAir9%2C1-lightgrey)]()

Field-tested scripts and configuration for installing and optimising [CachyOS](https://cachyos.org) on the 2020 Intel MacBook Air (MacBookAir9,1) with Apple T2 chip. Full documentation is available at **[iceunit.com](https://iceunit.com)**.

---

## Hardware Compatibility

| Component | Status | Notes |
|---|---|---|
| Wi-Fi (BCM4377b) | Working | `brcmfmac` — firmware extraction required |
| Bluetooth (BRCM4377) | Working | `hci_bcm4377` |
| Audio (T2) | Working | `apple-bce` + PipeWire |
| Keyboard / Trackpad | Working | Via `apple-bce` USB-over-PCIe |
| Graphics (Iris Plus G7) | Working | `i915` hardware acceleration |
| Display | Working | Full native resolution |
| NVMe | Working | TRIM via `discard=async` |
| Sleep / Wake | Mostly working | Suspend fix service recommended |
| Webcam | Partial | May require `apple-bce` updates |
| Thunderbolt | Limited | Basic USB-C works |
| Touch ID | Not supported | T2 Secure Enclave — inaccessible from Linux |

---

## Quick Start

```bash
git clone https://github.com/sebastienrousseau/cachyos-macbook-intel-2020.git
cd cachyos-macbook-intel-2020

# Fix thermal throttling (run immediately after install)
make thermal

# Apply system optimisations
make optimise

# Preview changes without modifying the system
make thermal DRY_RUN=1

# Or run everything via the interactive installer (requires Go)
make install
```

---

## Repository Structure

```
cachyos-macbook-intel-2020/
├── installer/                   # Go-based interactive Bubble Tea installer
├── scripts/
│   ├── 00-setup-vault.sh        # LUKS2 encrypted code vault creation
│   ├── 01-thermal-setup.sh      # Fan & thermal control (run first)
│   ├── 02-wifi-firmware.sh      # Wi-Fi & Bluetooth firmware management
│   ├── 03-optimise.sh           # Post-install system optimisation
│   ├── 04-bootloader.sh         # Limine + rEFInd boot management
│   ├── 05-mount-vault.sh        # Unlock and mount code vault
│   └── 06-unmount-vault.sh      # Lock and unmount code vault
├── tests/
│   ├── *.bats                   # 136 unit tests (bats-core)
│   ├── test_helper.bash         # Shared setup, mock framework
│   ├── Dockerfile.unit          # Arch Linux unit test container
│   ├── Dockerfile.integration   # Arch Linux integration test container
│   └── integration/             # Integration test scripts
├── docs/                        # VitePress documentation site
├── .github/workflows/           # CI: ShellCheck, unit & integration tests
├── Makefile                     # Build, test, lint, and docs targets
├── SECURITY.md                  # Security policy
├── CONTRIBUTING.md              # Contribution guidelines
└── LICENSE                      # MIT licence
```

## Scripts

| Script | Purpose | Run As | Docs |
|---|---|---|---|
| `00-setup-vault.sh` | Create LUKS2 encrypted vault | `make vault` | [Reference](https://iceunit.com/scripts/00-setup-vault) |
| `01-thermal-setup.sh` | Fix fan/thermal control | `make thermal` | [Reference](https://iceunit.com/scripts/01-thermal-setup) |
| `02-wifi-firmware.sh` | Manage Wi-Fi/BT firmware | `make wifi` | [Reference](https://iceunit.com/scripts/02-wifi-firmware) |
| `03-optimise.sh` | System-wide optimisation | `make optimise` | [Reference](https://iceunit.com/scripts/03-optimise) |
| `04-bootloader.sh` | Limine & boot management | `make bootloader` | [Reference](https://iceunit.com/scripts/04-bootloader) |
| `05-mount-vault.sh` | Unlock and mount vault | `make mount` | [Reference](https://iceunit.com/scripts/05-mount-vault) |
| `06-unmount-vault.sh` | Lock and unmount vault | `make unmount` | [Reference](https://iceunit.com/scripts/06-unmount-vault) |

All scripts support `DRY_RUN=1` to preview changes (e.g. `make thermal DRY_RUN=1`) and `--help` for usage information.

---

## Testing

```bash
make test-all           # Lint + unit + Go + Docker + integration tests
make lint               # ShellCheck + Go vet
make test               # Unit tests locally (requires bats-core)
make test-go            # Go unit tests for the installer
make test-docker        # Unit tests in Arch Linux Docker
make test-integration   # Integration tests in Arch Linux Docker
```

CI runs all checks automatically on every push and pull request. Run `make help` to see all available targets.

---

## Documentation

The full guide is hosted at **[iceunit.com](https://iceunit.com)** and covers:

- **Getting Started** — hardware specs, compatibility status, introduction
- **Pre-Installation** — T2 security, Wi-Fi firmware, bootable USB, partition layout
- **Installation** — running the CachyOS installer, Limine bootloader setup
- **Post-Installation** — thermal setup, system optimisation, encrypted vault
- **Reference** — troubleshooting, FAQ
- **Scripts** — detailed reference for all 7 scripts

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for script conventions, ShellCheck requirements, and the PR process.

## Security

See [SECURITY.md](SECURITY.md) for the responsible disclosure process and security considerations.

## References

- [CachyOS T2 MacBook Installation Wiki](https://wiki.cachyos.org/installation/installation_t2macbook/)
- [T2 Linux Project](https://t2linux.org)
- [t2linux Wi-Fi Firmware Guide](https://wiki.t2linux.org/guides/wifi-bluetooth/)
- [apple-bce kernel module](https://github.com/t2linux/apple-bce-drv)
- [mbpfan](https://github.com/linux-on-mac/mbpfan)
- [arch-mact2 firmware mirror](https://mirror.funami.tech/arch-mact2/)

## Licence

[MIT](LICENSE) — configurations and scripts are based on field testing on a MacBook Air 2020 (MacBookAir9,1) running CachyOS with kernel 6.19.x.

<p align="center">
  THE ARCHITECT ᛫ <a href="https://sebastien.sh">Sebastien Rousseau</a><br/>
  THE ENGINE ᛞ <a href="https://euxis.com">EUXIS</a> ᛫ Enterprise Unified Execution Intelligence System
</p>
