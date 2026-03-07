# Hardware Status

Current compatibility status on CachyOS kernel 6.19.x.

## Compatibility Table

| Hardware | Status | Notes |
|---|---|---|
| **Wi-Fi** (BCM4377b) | ✅ Working | `brcmfmac`, firmware in `/lib/firmware/brcm/` |
| **Bluetooth** (BRCM4377) | ✅ Working | `hci_bcm4377` |
| **Audio** (T2) | ✅ Working | `apple_bce` → PipeWire, speakers + mic |
| **Keyboard** | ✅ Working | Via `apple_bce` USB-over-PCIe |
| **Trackpad** | ✅ Working | Via `apple_bce`, gestures supported |
| **Touch ID** | ❌ Not supported | T2 Secure Enclave — no Linux access |
| **Graphics** (Iris Plus G7) | ✅ Working | `i915`, hardware acceleration available |
| **Display** | ✅ Working | Internal display at full resolution |
| **Webcam** | ⚠️ Partial | May need `apple_bce` updates; check `v4l2-ctl --list-devices` |
| **Sleep / Wake** | ⚠️ Mostly working | Run `01-thermal-setup.sh` and `03-optimise.sh` |
| **USB-C Charging** | ✅ Working | Both USB-C ports charge |
| **USB-C Data** | ✅ Working | Standard USB-C devices work |
| **Thunderbolt** | ⚠️ Limited | Basic USB-C works; TB-specific features may not |
| **NVMe** | ✅ Working | Full speed; async TRIM via `discard=async` |
| **Fan Control** | ✅ Working | Requires `mbpfan` — see [Thermal Setup](/guide/thermal-setup) |
| **Brightness Keys** | ✅ Working | Standard kernel backlight control |
| **Volume Keys** | ✅ Working | Via `apple_bce` |
| **MagSafe / USB-C** | ✅ Working | Power delivery works on both ports |

## Known Issues

### Keyboard / Trackpad Freeze After Wake

Occasionally after suspend/resume, the keyboard and trackpad stop responding. This is caused by the `apple_bce` driver not cleanly reinitialising on wake.

**Fix:** The `macbook-suspend-fix.service` installed by `03-optimise.sh` reloads `apple_bce` automatically on every resume. Manual fix:

```bash
sudo modprobe -r apple_bce && sudo modprobe apple_bce
```

### Audio Crackling or Pops

The apple-bce audio driver can produce xruns (buffer underruns) with default PipeWire settings. The `03-optimise.sh` script applies a PipeWire config that increases the quantum buffer size to 1024 frames.

```bash
# Apply fix
bash scripts/03-optimise.sh --audio-only
systemctl --user restart pipewire pipewire-pulse
```

### Webcam

The FaceTime HD camera status varies by kernel version. Check:

```bash
v4l2-ctl --list-devices
```

If no device appears, it may not be supported in the current kernel version. Check the [T2 Linux roadmap](https://t2linux.org/roadmap/) for camera status.
