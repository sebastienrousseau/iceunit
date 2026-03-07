# System Optimisation

The `03-optimise.sh` script applies a set of post-install optimisations specific to the MacBook Air 2020 and CachyOS.

## What the Script Does

### Kernel Parameters

Adds the following to `/etc/kernel/cmdline` (Limine reads this) or the appropriate bootloader config:

```
intel_idle.max_cstate=1    # Prevent deep C-states that cause wake latency
nmi_watchdog=0             # Disable NMI watchdog (reduces overhead)
nowatchdog                 # Disable software watchdog
```

### TLP Power Management

Writes `/etc/tlp.d/50-macbook-air.conf` with Ice Lake-specific settings:
- CPU governor: `powersave` on battery, `performance` on AC
- PCIe ASPM enabled on battery
- USB autosuspend enabled with MacBook-specific exclusions (keyboard/trackpad USB IDs)

::: warning TLP vs power-profiles-daemon conflict
Both TLP and `power-profiles-daemon` may be running simultaneously, which causes power management conflicts. The script disables `power-profiles-daemon` and leaves TLP in control.
:::

### PipeWire Audio Fix

Writes `~/.config/pipewire/pipewire.conf.d/10-macbook-audio.conf`:
```
context.properties = {
    default.clock.quantum     = 1024
    default.clock.min-quantum = 1024
}
```

This increases the audio buffer to prevent xruns (crackling/pops) on the apple-bce audio path.

### Suspend Fix Service

Installs `/etc/systemd/system/macbook-suspend-fix.service`:
- Runs on every resume from suspend
- Reloads `apple_bce` if keyboard/trackpad become unresponsive after wake
- Reloads `brcmfmac` to restore Wi-Fi after deep sleep

## Running

```bash
sudo bash scripts/03-optimise.sh
```

Or to apply just the audio fix without other changes:
```bash
bash scripts/03-optimise.sh --audio-only
systemctl --user restart pipewire pipewire-pulse
```

## BTRFS Mount Options

After running the script, consider updating your `/etc/fstab` BTRFS entries manually for best NVMe performance. See [Partition Layout](/guide/partition-layout#recommended-mount-options).
