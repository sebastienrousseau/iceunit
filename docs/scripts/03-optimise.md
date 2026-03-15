---
description: 03-optimise.sh applies kernel params, sysctl tuning, TLP power management, PipeWire audio, and suspend service.
---

# 03-optimise.sh

**Status: Recommended**

Applies post-install system optimisations for the MacBook Air 2020 running CachyOS.
 Covers kernel parameters, sysctl tuning, TLP power management, PipeWire audio, BTRFS options, suspend/resume, and package installation.

## Usage

```bash
# Full system optimisation (requires root)
sudo bash scripts/03-optimise.sh

# Audio fix only (no root required)
bash scripts/03-optimise.sh --audio-only
systemctl --user restart pipewire pipewire-pulse

# Preview without changes
sudo bash scripts/03-optimise.sh --dry-run
bash scripts/03-optimise.sh --help
```

| Flag | Description |
|---|---|
| `--dry-run` | Preview all actions without modifying the system |
| `--audio-only` | Apply PipeWire audio config only (no root required) |
| `--help` | Show usage information and exit |

## Execution Model

| Invocation | Sections |
|---|---|
| `sudo bash 03-optimise.sh` | Kernel params, sysctl, TLP, BTRFS, sleep, packages, ZRAM check, power profiles; then calls `--audio-only` as `$SUDO_USER` |
| `bash 03-optimise.sh --audio-only` | PipeWire audio config only (user-level) |
| `bash 03-optimise.sh` (no sudo) | Audio fix, ZRAM check, power profiles check |

## What It Does

### 1. Kernel Parameters
Appends to `/etc/kernel/cmdline`: `intel_idle.max_cstate=4`, `snd_hda_intel.power_save=0`, `pcie_aspm=off`, `mem_sleep_default=deep`. Skips any parameter already present.

### 2. sysctl Rules
Writes `/etc/sysctl.d/99-macbook-air-2020.conf` with `vm.swappiness=10`, `vm.vfs_cache_pressure=50`, NVMe-friendly writeback intervals, TCP Fast Open, and NMI watchdog disabled.

### 3. TLP Drop-in Config
Writes `/etc/tlp.d/10-macbook-air-2020.conf` with Ice Lake CPU tuning, Wi-Fi power management disabled, USB autosuspend disabled, and T2 audio power save disabled.

### 4. BTRFS Mount Options
Displays recommended fstab options (`noatime,compress=zstd:1,space_cache=v2,autodefrag,discard=async`). Applies `noatime` live via remount. Starts background defragmentation of `/home`. The root UUID is detected automatically.

### 5. PipeWire Audio
Writes `~/.config/pipewire/pipewire.conf.d/10-t2-macbook-audio.conf` with `quantum=1024`, `min-quantum=256`, `max-quantum=2048` at 48 kHz.

### 6. Suspend / Resume
Confirms deep sleep is active. Installs `macbook-suspend-fix.service` that reloads `apple-bce` on resume.

### 7. ZRAM Verification
Confirms ZRAM is configured (no changes made).

### 8. Intel i915 GUC/HUC
Writes `/etc/modprobe.d/i915.conf` with `enable_guc=3 enable_fbc=1` to offload GPU scheduling and video decode to firmware. Reduces CPU load during video playback on the Ice Lake Iris Plus G7.

### 9. RTC UTC Clock Sync
Sets the hardware clock to UTC (`timedatectl set-local-rtc 0`) to match macOS, which also uses UTC. Prevents the clock from jumping by several hours each time you switch operating systems.

### 10. Power Profiles Check
Warns if both TLP and `power-profiles-daemon` are active. Does **not** disable either — this is a manual decision.

## Files Modified

| Path | Purpose |
|---|---|
| `/etc/kernel/cmdline` | Kernel boot parameters |
| `/etc/sysctl.d/99-macbook-air-2020.conf` | sysctl tuning rules |
| `/etc/tlp.d/10-macbook-air-2020.conf` | TLP power management drop-in |
| `~/.config/pipewire/pipewire.conf.d/10-t2-macbook-audio.conf` | PipeWire audio buffer config |
| `/etc/systemd/system/macbook-suspend-fix.service` | Suspend resume fix |
| `/etc/modprobe.d/i915.conf` | Intel GUC/HUC firmware offloading |

## Prerequisites

- Root access for all sections except `--audio-only`
- TLP installed (`pacman -S tlp`) for power management section
- PipeWire running for audio section

::: tip Source
View the full source on [GitHub](https://github.com/sebastienrousseau/cachyos-macbook-intel-2020/blob/main/scripts/03-optimise.sh).
:::
