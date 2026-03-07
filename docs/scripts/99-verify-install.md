---
description: Comprehensive system health audit for Iceunit. Verifies packages, services, kernel parameters, firmware, and storage mounts.
---

# System Health Audit

**Status: Recommended**

The `99-verify-install.sh` script provides a high-fidelity audit of your MacBook Air 2020's configuration.
 It is designed to match the Iceunit professional aesthetic.

## Audit Categories

### 1. Package Verification
Scans the local `pacman` database to ensure every required dependency from the `00-system-init` phase is present and accounted for.

### 2. Service Health
Verifies the active status of critical background daemons:
- **Thermal Control**: Checks if `mbpfan` is actively managing your fans.
- **Power Management**: Confirms `TLP` is active and `power-profiles-daemon` is masked.
- **Security**: Ensures the `UFW` firewall is protecting your network.
- **Containers**: Validates that `Docker` or `Podman` is ready for dev work.

### 3. Hardware Optimisation
Inspects configuration files and the active kernel state:
- **T2 Compatibility**: Checks for `intel_idle.max_cstate=4` and other critical T2 parameters.
- **Sleep Mode**: Confirms `deep` sleep is the default.
- **Performance**: Validates Ice Lake-specific `sysctl` tweaks.

### 4. Firmware & Storage
- **BCM4377b**: Ensures Wi-Fi and Bluetooth firmware files are in the correct directory.
- **Code Vault**: Checks for the existence of the LUKS2 image and confirms it is mounted at `~/Code`.

## Running

```bash
make verify
```

## Visual Indicators

| Icon | Meaning | Action |
|---|---|---|
| **`✓`** (Green) | Active & Healthy | None |
| **`>`** (Purple) | Pending Success | **Reboot required** to apply changes. |
| **`✗`** (Red) | Failed / Missing | Run `sudo make install` to fix. |
