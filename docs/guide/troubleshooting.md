# Troubleshooting

## CPU Running at 100°C

**Symptom:** `sensors` shows Package id 0 at or near 100°C, fan spinning at ~2700 RPM.

**Cause:** `thermald` cannot find the fan at the expected `applesmc` path on this kernel.

**Fix:**
```bash
paru -S mbpfan
sudo bash scripts/01-thermal-setup.sh
```

Emergency fan override while the script installs:
```bash
find /sys/devices/LNXSYSTM:00 -name "fan1_output"
# Use the path returned above
echo 1 | sudo tee <path>/fan1_manual
echo 8000 | sudo tee <path>/fan1_output
```

---

## Wi-Fi Not Working After Reinstall

**Cause:** Broadcom BCM4377b firmware is proprietary and not preserved across reinstalls.

**Fix:**
```bash
sudo bash scripts/02-wifi-firmware.sh install-pkg
```

---

## Keyboard / Trackpad Frozen After Wake

**Cause:** `apple_bce` driver doesn't cleanly reinitialise after suspend/resume.

**Fix (immediate):**
```bash
sudo modprobe -r apple_bce && sudo modprobe apple_bce
```

**Fix (permanent):** Run `03-optimise.sh` which installs `macbook-suspend-fix.service` to do this automatically on every resume.

---

## Audio Crackling or Pops

**Cause:** Default PipeWire quantum buffer is too small for the apple-bce audio path.

**Fix:**
```bash
bash scripts/03-optimise.sh --audio-only
systemctl --user restart pipewire pipewire-pulse
```

If audio device disappears entirely:
```bash
sudo modprobe -r snd_hda_intel apple_bce
sudo modprobe apple_bce snd_hda_intel
```

---

## Script Hangs After Starting

**Cause:** Running scripts from fish shell — glob patterns like `applesmc.*` cause fish to abort before bash even starts.

**Fix:** Always invoke scripts with `bash` explicitly:
```bash
sudo bash scripts/01-thermal-setup.sh   # ✅ correct
sudo scripts/01-thermal-setup.sh        # ❌ fish will try to interpret it
```

---

## `modprobe apple-bce` Fails

**Cause:** `apple_bce` is compiled into the CachyOS kernel (`CONFIG_APPLE_BCE=y`), not as a loadable module. `modprobe` cannot load what's already built in.

**This is not a problem** — if your keyboard and trackpad work, `apple_bce` is active. Verify:
```bash
lsmod | grep apple_bce
```

---

## Cannot Boot After Kernel Update

Hold **Space** at the Limine splash to access the snapshot menu and boot the last known good snapshot. Then:

```bash
# Check installed kernel
pacman -Q linux-cachyos

# Downgrade from cache if needed
sudo pacman -U /var/cache/pacman/pkg/linux-cachyos-*.pkg.tar.zst
```

---

## macOS Won't Boot

```bash
# Check boot order
sudo efibootmgr

# Force macOS on next boot only
sudo efibootmgr -n 0080
```

---

## Vault Won't Mount

```bash
# Check if image exists
ls -lh ~/.vault.img

# Check if already open
ls /dev/mapper/code_vault

# Manual open and mount
sudo cryptsetup open ~/.vault.img code_vault
sudo mount /dev/mapper/code_vault ~/Code
sudo chown -R $USER:$USER ~/Code
```
