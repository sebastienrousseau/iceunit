---
description: 01-thermal-setup.sh installs mbpfan with the correct fan curve for the MacBook Air 2020 Apple SMC on CachyOS.
---

# 01-thermal-setup.sh

Installs and configures `mbpfan` for proper fan control on the MacBook Air 2020. Without this script, the default `thermald` configuration does not drive the Apple SMC fan correctly — the CPU can sustain 97-100 °C at near-minimum fan speed.

## Usage

```bash
sudo bash scripts/01-thermal-setup.sh
```

Requires root. Run this **immediately** after installing CachyOS.

## What It Does

1. **Preflight** — locates the Apple SMC sysfs path (`applesmc` or `APP0001:00`), displays current temperatures and fan speed
2. **Install mbpfan** — installs from the AUR via `paru` or `yay` (runs as the invoking user, not root)
3. **Write config** — creates `/etc/mbpfan.conf` with the fan curve below
4. **Configure thermald** — writes `/etc/thermald/thermal-conf.xml` limiting thermald to Intel RAPL power capping only (no fan control)
5. **Enable services** — restarts `thermald` with the new config, enables and starts `mbpfan.service`
6. **Verify** — displays fan speed, service status, and current temperatures

## Fan Curve

| Temperature | Fan Speed | Behaviour |
|---|---|---|
| Below 55 °C | 2700 RPM | Near-silent idle |
| 55-70 °C | 2700-4500 RPM | Linear ramp (normal use) |
| 70-85 °C | 4500-6500 RPM | Aggressive ramp (heavy load) |
| Above 85 °C | 8000 RPM | Maximum (thermal protection) |

Hysteresis: fan speed does not reduce until the temperature drops 4 °C below the threshold (`temp_change_factor = 4`).

## Files Modified

| Path | Purpose |
|---|---|
| `/etc/mbpfan.conf` | Fan curve configuration |
| `/etc/thermald/thermal-conf.xml` | RAPL-only thermald config (no fan zones) |

## ACPI Path Detection

The script searches two locations for the Apple SMC fan interface:

1. `/sys/devices/platform/applesmc*` (standard path)
2. `/sys/devices/LNXSYSTM:00/.../APP0001:00` (ACPI namespace fallback)

If neither is found, `mbpfan` still works — it reads temperature via `coretemp` sensors and controls the fan through its own kernel interface.

## Prerequisites

- An AUR helper (`paru` or `yay`)
- `lm_sensors` (for the `sensors` verification command)

::: tip Source
View the full source on [GitHub](https://github.com/sebastienrousseau/cachyos-macbook-intel-2020/blob/main/scripts/01-thermal-setup.sh).
:::
