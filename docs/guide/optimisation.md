# System Optimisation

The `03-optimise.sh` script applies post-install optimisations specific to the MacBook Air 2020 running CachyOS. It can be run as root for full system tuning, or as a normal user for audio-only configuration.

## Running

```bash
# Full optimisation (kernel, TLP, BTRFS, sleep, packages)
sudo bash scripts/03-optimise.sh

# Audio fix only (no root required)
bash scripts/03-optimise.sh --audio-only
systemctl --user restart pipewire pipewire-pulse
```

## What the Script Does

### 1. Kernel Parameters

Adds the following to `/etc/kernel/cmdline` (read by `limine-entry-tool`):

| Parameter | Purpose |
|---|---|
| `intel_idle.max_cstate=4` | Allow efficient C-states while avoiding audio pops |
| `snd_hda_intel.power_save=0` | Disable HDA power save for T2 audio stability |
| `pcie_aspm=off` | Prevent PCIe conflicts with the T2 bridge |
| `mem_sleep_default=deep` | Use deep sleep (S3-equivalent) by default |

::: info Limine integration
Do not edit `/boot/limine.conf` directly. The script updates `/etc/kernel/cmdline` and `limine-entry-tool` regenerates boot entries automatically on kernel updates.
:::

### 2. sysctl Tuning

Writes `/etc/sysctl.d/99-macbook-air-2020.conf`:

| Setting | Value | Rationale |
|---|---|---|
| `vm.swappiness` | `10` | ZRAM is 15.4 GB — prefer keeping data in RAM |
| `vm.vfs_cache_pressure` | `50` | Retain filesystem cache longer |
| `vm.dirty_writeback_centisecs` | `6000` | Reduce NVMe write frequency for BTRFS |
| `vm.dirty_expire_centisecs` | `6000` | Match writeback interval |
| `net.core.netdev_max_backlog` | `4096` | Network performance |
| `net.ipv4.tcp_fastopen` | `3` | Enable TCP Fast Open (client + server) |
| `kernel.nmi_watchdog` | `0` | Reduce overhead (nowatchdog already in cmdline) |

### 3. TLP Power Management

Writes `/etc/tlp.d/10-macbook-air-2020.conf` with Ice Lake-specific settings:

- **CPU governor:** `performance` on AC, `powersave` on battery
- **CPU boost:** enabled on AC, disabled on battery
- **Wi-Fi power management:** disabled (BCM4377b disconnects under power management)
- **USB autosuspend:** disabled (`USB_AUTOSUSPEND=0`) for T2 BCE bridge stability
- **Sound power save:** disabled on both AC and battery (prevents T2 audio crackling)
- **PCIe ASPM:** set to `default` (disabled globally via kernel cmdline)

### 4. PipeWire Audio Fix

Writes `~/.config/pipewire/pipewire.conf.d/10-t2-macbook-audio.conf`:

```ini
context.properties = {
    default.clock.rate          = 48000
    default.clock.quantum       = 1024
    default.clock.min-quantum   = 256
    default.clock.max-quantum   = 2048
}
```

This increases the audio buffer to prevent xruns (crackling/pops) on the `apple-bce` audio path. The minimum quantum is 256 frames, not 1024 — this allows low-latency applications to request smaller buffers when needed.

### 5. BTRFS Mount Options

The script displays recommended mount options for `/etc/fstab` but does **not** edit fstab automatically (too risky). It applies `noatime` live via `mount -o remount` and starts a background defragmentation of `/home`.

Recommended fstab options:
```
noatime,compress=zstd:1,space_cache=v2,autodefrag,discard=async
```

The root UUID is detected automatically via `findmnt`.

### 6. Suspend / Resume Fix

Installs `/etc/systemd/system/macbook-suspend-fix.service`:
- Runs on every resume from suspend
- Reloads the `apple-bce` module to restore keyboard/trackpad if they freeze after wake

::: warning
The service only reloads `apple-bce`. Wi-Fi (`brcmfmac`) is **not** reloaded by this service — it generally survives suspend without issues.
:::

### 7. ZRAM Verification

Confirms that ZRAM is correctly configured (15.4 GB, zstd compression). No changes are made — CachyOS configures this during installation.

### 8. Power Profiles Daemon

Checks whether both TLP and `power-profiles-daemon` are active. If both are running, the script **warns about the conflict** and shows the commands to disable one or the other. It does not disable either service automatically — this is a manual decision.

## Execution Model

The script has two execution paths:

| Invocation | Sections Run |
|---|---|
| `sudo bash 03-optimise.sh` | Kernel params, sysctl, TLP, BTRFS, sleep, packages, ZRAM check, power profiles, then calls `--audio-only` as `$SUDO_USER` |
| `bash 03-optimise.sh --audio-only` | PipeWire audio config only (user-level, no root) |

Running without sudo applies only the audio fix, ZRAM check, and power profiles check.
