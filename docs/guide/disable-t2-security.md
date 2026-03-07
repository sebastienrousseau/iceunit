---
description: Disable Apple T2 Startup Security and allow external boot on the MacBook Air 2020 for CachyOS installation.
---

# Disable T2 Security

Before installing any non-Apple OS, you must lower the Startup Security level in macOS Recovery. The T2 chip enforces boot policy — without this step, Limine and CachyOS will not boot.

::: warning macOS required
This step requires booting into macOS Recovery. If macOS has already been erased, you may need to restore it via Apple Configurator 2 first.
:::

## Steps

### 1. Boot into macOS Recovery

Hold **⌘ + R** immediately when pressing the power button. Keep holding until you see the Apple logo or a spinning globe.

### 2. Open Startup Security Utility

From the menu bar: **Utilities → Startup Security Utility**

Authenticate with your admin password when prompted.

### 3. Set Security Policy

Under **Secure Boot**, select:
> **No Security** — Does not enforce any requirements on the bootable OS

Under **Allowed Boot Media**, select:
> **Allow booting from external or removable media**

### 4. Restart

Close the utility and restart normally. T2 will now allow booting unsigned OS loaders.

## What This Changes

| Setting | Before | After |
|---|---|---|
| Secure Boot | Full Security | No Security |
| External Boot | Not allowed | Allowed |

::: info About T2 and security
Setting "No Security" disables Apple's Secure Boot enforcement only. The T2 chip continues to protect the Secure Enclave (Touch ID keys, encrypted storage keys at rest). Your data at rest is still protected by the T2 hardware encryption.
:::

## Next Steps

→ Continue to [Wi-Fi Firmware](/guide/wifi-firmware) — download firmware files before creating the USB, so they're ready during install.
