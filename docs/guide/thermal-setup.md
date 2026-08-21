---
description: Fix MacBook Air 2020 thermal throttling on CachyOS by installing mbpfan for Apple SMC fan control via the APP0001:00 ACPI path.
verifiedOn: 2026-04-01
---

# Thermal Setup

::: danger Run this first
Without intervention, the MacBook Air 2020 CPU can sustain **97–100°C** at near-idle fan speeds on CachyOS. This is not a minor issue — it risks hardware damage over time. Run `01-thermal-setup.sh` immediately after installing.
:::

## Why This Happens

The default `thermald` configuration expects the fan to be at the traditional `applesmc` platform sysfs path. On the MacBook Air 2020 running kernel 6.19.x-cachyos, the fan is instead exposed via the **ACPI `APP0001:00` device**:

```
/sys/devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A08:00/device:1c/APP0001:00/
```

`thermald` cannot find the fan at its expected path, so the fan stays near minimum speed (~2700 RPM) regardless of CPU temperature.

## The Fix: mbpfan

[mbpfan](https://github.com/linux-on-mac/mbpfan) reads Apple SMC sensors directly via `coretemp` and drives the fan independently of `thermald`. The `01-thermal-setup.sh` script:

1. Installs `mbpfan` via your AUR helper
2. Writes `/etc/mbpfan.conf` with the correct fan curve for this hardware
3. Writes `/etc/thermald/thermal-conf.xml` to restrict `thermald` to Intel RAPL power capping only (no fan control)
4. Enables and starts `mbpfan.service`

## Running the Script

This repository handles everything automatically through the interactive installer (`make install`), but if you want to run it manually:

```bash
# Install as your normal user first (AUR helpers cannot run as root)
paru -S mbpfan

# Then run the setup script
sudo bash scripts/01-thermal-setup.sh
```

## Fan Curve

| CPU Temperature | Fan Speed |
|---|---|
| Below 55°C | 2700 RPM (near-silent) |
| 55–70°C | Linear ramp to 4500 RPM |
| 70–80°C | Ramp to 6500 RPM |
| 80–85°C | 6500 → 8000 RPM |
| Above 85°C | 8000 RPM (maximum) |

## Monitoring

After running the script, monitor for 2 minutes:

```bash
watch -n 2 'sensors | grep -E "Package|fan1"'
```

Expected: temperatures should drop from 100°C to below 70°C within a few minutes at idle. Fan speed will rise to match load.

## Emergency Fan Override

If your CPU is critically hot before running the script:

```bash
# Find your fan sysfs path
find /sys/devices/LNXSYSTM:00 -name "fan1_output" 2>/dev/null

# Force fan to maximum (replace path with yours)
echo 1 | sudo tee /sys/devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A08:00/device:1c/APP0001:00/fan1_manual
echo 8000 | sudo tee /sys/devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A08:00/device:1c/APP0001:00/fan1_output

# Return to automatic control
echo 0 | sudo tee /sys/devices/LNXSYSTM:00/LNXSYBUS:00/PNP0A08:00/device:1c/APP0001:00/fan1_manual
```

## Verifying mbpfan is Running

```bash
systemctl status mbpfan
sudo journalctl -u mbpfan -n 30 --no-pager
```
