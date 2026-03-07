# CachyOS on MacBook Air 2020 (Intel)

A complete, field-tested guide to installing and optimising CachyOS on a 2020 Intel MacBook Air. Every configuration detail in this repo has been verified against a live running system.

---

## 💻 System Specifications

| Component | Specification | Driver / Module |
|---|---|---|
| **Model** | Apple MacBook Air 2020 (MacBookAir9,1) | — |
| **OS** | CachyOS | — |
| **Kernel** | 6.19.x-cachyos | linux-cachyos |
| **CPU** | Intel Core i5-1030NG7 @ 1.10GHz (Ice Lake) | intel_idle, intel_pstate |
| **Graphics** | Intel Iris Plus Graphics G7 (Ice Lake) | i915 |
| **Security / Audio** | Apple T2 Bridge & Secure Enclave | apple-bce |
| **Wi-Fi** | Broadcom BCM4377b | brcmfmac |
| **Bluetooth** | Broadcom BRCM4377 | hci_bcm4377 |
| **Storage** | Apple NVMe (nvme0n1) | nvme |
| **Bootloader** | Limine 10.8.2 | limine-entry-tool |
| **Audio** | Apple T2 Audio via apple-bce | PipeWire 1.6.0 |
| **Swap** | ZRAM 15.4G (zstd) | zram-generator |

---

## 🗂 Repository Structure

```
cachyos-macbook-intel-2020/
├── README.md
└── scripts/
    ├── 01-thermal-setup.sh      # Fan & temperature control (URGENT — run first)
    ├── 02-wifi-firmware.sh      # Wi-Fi & Bluetooth firmware management
    ├── 03-optimise.sh           # Post-install system optimisation
    └── 04-bootloader.sh         # Limine + rEFInd dual-boot management
```

---

## ⚠️ Critical: Thermal Issue

The default `thermald` configuration does **not** correctly control the fan on T2 MacBooks. Left unconfigured, the CPU can sustain **97–100°C** at near-minimum fan speed, risking hardware damage.

**Run this immediately after installing CachyOS:**

```bash
sudo bash scripts/01-thermal-setup.sh
```

This installs and configures `mbpfan` to read Apple SMC sensors and drive the fan correctly.

---

## 📋 Table of Contents

1. [Pre-Installation: macOS Setup](#-pre-installation-macos-setup)
2. [Wi-Fi Firmware](#-wi-fi-firmware-critical-pre-install-step)
3. [Disk Layout](#-disk-layout)
4. [Installation](#-installation)
5. [Bootloader: Limine](#-bootloader-limine)
6. [Post-Install: Thermal Setup](#-post-install-thermal-setup-run-first)
7. [Post-Install: System Optimisation](#-post-install-system-optimisation)
8. [Hardware Status](#-hardware-status)
9. [Encrypted Code Vault](#-encrypted-code-vault-optional)
10. [Troubleshooting](#-troubleshooting)

---

## 🔓 Pre-Installation: macOS Setup

### 1. Disable T2 Security

The T2 chip blocks booting from external media by default.

1. Shut down the MacBook completely.
2. Power on and immediately hold **⌘ + R** to enter Recovery Mode.
3. Go to **Utilities → Startup Security Utility**.
4. Authenticate, then set:
   - **Secure Boot:** No Security
   - **Allowed Boot Media:** Allow booting from external or removable media
5. Close and shut down.

### 2. Create a macOS Partition for Linux (Recommended)

Keeping macOS is strongly recommended — it's the only way to receive T2 firmware updates from Apple.

1. Open **Disk Utility** in macOS.
2. Select **Macintosh HD → Partition**.
3. Add a new partition (at least 50GB, format doesn't matter — CachyOS will reformat it).
4. Name it something recognisable (e.g. "CachyOS").
5. Click **Apply**.

### 3. Create a Bootable CachyOS USB

```bash
# On macOS — replace /dev/diskX with your USB drive (check with diskutil list)
diskutil unmountDisk /dev/diskX
sudo dd if=cachyos-desktop-linux-*.iso of=/dev/rdiskX bs=4m status=progress
```

Alternatively, use [Fedora Media Writer](https://flathub.org/apps/org.fedoraproject.MediaWriter).

---

## 📡 Wi-Fi Firmware (Critical Pre-Install Step)

The Broadcom BCM4377b firmware is **proprietary** and cannot be included in the CachyOS ISO. Wi-Fi will not work during installation without this step.

### Option A — Extract from macOS (Recommended)

Run these commands in the **CachyOS live environment** before starting the installer:

```bash
# 1. Find and mount the macOS partition
lsblk -f  # identify your macOS APFS partition

# 2. Run the T2 firmware extraction script
# This auto-detects your board ID (fiji for MacBook Air 2020) and
# copies the correct brcmfmac4377b3 files to /lib/firmware/brcm/
curl -s https://wiki.t2linux.org/tools/firmware.sh | sudo bash

# 3. Verify Wi-Fi is now working
sudo modprobe brcmfmac
nmcli device wifi list
```

### Option B — arch-mact2 Pre-packaged Firmware

If macOS is no longer accessible:

```bash
curl https://mirror.funami.tech/arch-mact2/os/x86_64/apple-bcm-firmware-14.0-1-any.pkg.tar.zst \
    -o /tmp/apple-bcm-firmware.pkg.tar.zst

sudo tar -xf /tmp/apple-bcm-firmware.pkg.tar.zst -C /
sudo modprobe brcmfmac
```

### Option C — USB Tethering During Install

Connect your iPhone via USB, enable Personal Hotspot → USB. The RNDIS interface will appear automatically. Fix Wi-Fi post-install.

### Post-Install Firmware Management

```bash
# Verify firmware health
bash scripts/02-wifi-firmware.sh verify

# Back up firmware files
bash scripts/02-wifi-firmware.sh backup

# Re-install if firmware is lost
sudo bash scripts/02-wifi-firmware.sh install-pkg
```

**Firmware files for MacBook Air 2020 (board ID: fiji):**
- `brcmfmac4377b3-pcie.apple,fiji.bin`
- `brcmfmac4377b3-pcie.apple,fiji.clm_blob`
- `brcmfmac4377b3-pcie.apple,fiji.txcap_blob`
- `brcmbt4377b3-apple,formosa.bin` (Bluetooth)

---

## 💽 Disk Layout

This setup uses a two-partition layout with BTRFS subvolumes and ZRAM (no dedicated swap partition).

### Physical Partitions

| Device | Size | FS | Mount | Notes |
|---|---|---|---|---|
| `nvme0n1p1` | 4GB | FAT32 | `/boot` | ESP — Limine bootloader |
| `nvme0n1p2` | ~256GB | BTRFS | `/` | Root with subvolumes |
| `loop0` | 60GB | BTRFS (LUKS2) | `~/Code` | Encrypted code vault |
| `zram0` | 15.4GB | swap | `[SWAP]` | ZRAM with zstd compression |

### BTRFS Subvolumes

```
nvme0n1p2
├── @           → /
├── @home       → /home
├── @var        → /var
├── @var/log    → /var/log
├── @var/cache  → /var/cache
├── @var/tmp    → /var/tmp
├── @srv        → /srv
├── @root       → /root
└── @.snapshots → /.snapshots   (snapper + limine-snapper-sync)
```

### Recommended BTRFS Mount Options

Add these options to your BTRFS entries in `/etc/fstab`:

```
noatime,compress=zstd:1,space_cache=v2,autodefrag,discard=async
```

Example root entry:
```
UUID=<your-uuid>  /  btrfs  rw,noatime,compress=zstd:1,space_cache=v2,autodefrag,discard=async,subvol=/@  0 0
```

### No Swap Partition

Swap is handled entirely by ZRAM (15.4G, zstd compression). This eliminates wear on the NVMe drive from swap writes and provides faster swap performance than disk-based swap.

```bash
# Verify ZRAM
zramctl
```

---

## 🖥 Installation

### 1. Boot the CachyOS Installer

1. Insert the CachyOS USB.
2. Power on and immediately hold **Option (⌥)**.
3. Select the yellow EFI Boot drive.

### 2. Set Up Wi-Fi in the Live Environment

Follow [Option A above](#option-a--extract-from-macos-recommended) before proceeding.

### 3. Run the Calamares Installer

1. Click **Launch Installer**.
2. **Partitioning:** Select **Manual** and configure as described in [Disk Layout](#-disk-layout).
3. **Bootloader:** Select **Limine** (recommended — has native BTRFS snapshot support).
4. Complete the installation.

### 4. First Boot

The CachyOS Hardware Detection tool (`chwd`) will automatically apply T2-specific boot parameters during installation. After first boot, verify with:

```bash
cat /proc/cmdline
# Expected: ... intel_iommu=on iommu=pt or similar T2 params
```

---

## 🥾 Bootloader: Limine

CachyOS installs **Limine 10.8.2** by default. It integrates with `limine-entry-tool` and `limine-snapper-sync` to automatically manage kernel entries and BTRFS snapshot boot entries.

### Key Files

| File | Purpose |
|---|---|
| `/boot/limine.conf` | Auto-generated boot config — **do not edit directly** |
| `/etc/kernel/cmdline` | Kernel parameters — edit this file |
| `limine-entry-tool` | Regenerates `/boot/limine.conf` on kernel updates |
| `limine-snapper-sync` | Syncs BTRFS snapshots into Limine boot menu |

### Updating Kernel Parameters

```bash
# Edit kernel cmdline
sudo nano /etc/kernel/cmdline

# Recommended parameters for MacBook Air 2020
quiet nowatchdog splash rw intel_idle.max_cstate=4 snd_hda_intel.power_save=0 pcie_aspm=off mem_sleep_default=deep

# Regenerate Limine entries
sudo limine-entry-tool
```

### BTRFS Snapshot Booting

You have 8 snapshots available in the boot menu via `limine-snapper-sync`. To boot from a snapshot:

1. Hold **Space** at the Limine splash screen.
2. Select **CachyOS → Snapshots**.
3. Choose a snapshot by date and description.

To roll back to a snapshot permanently:

```bash
sudo snapper rollback <snapshot_number>
sudo reboot
```

### Optional: Adding rEFInd as a Graphical Boot Picker

rEFInd provides a graphical boot picker with auto-detection of macOS and Linux. Install it as a **secondary** option alongside Limine:

```bash
sudo bash scripts/04-bootloader.sh refind
```

This installs rEFInd without changing the default boot order. Access it by holding **Option (⌥)** at startup.

### Boot Order Management

```bash
# Show current EFI boot entries and order
sudo efibootmgr

# Boot into macOS on next boot only (then reverts to CachyOS)
sudo efibootmgr -n 0080

# Set permanent boot order (Limine first, macOS second)
sudo efibootmgr -o 0001,0080

# Interactive boot management
sudo bash scripts/04-bootloader.sh
```

---

## 🌡 Post-Install: Thermal Setup (Run First)

**The default `thermald` configuration does not drive the applesmc fan correctly on T2 MacBooks. This is not a minor issue — cores can sustain 100°C at near-idle fan speeds.**

```bash
sudo bash scripts/01-thermal-setup.sh
```

What this script does:

- Installs `mbpfan` (reads Apple SMC sensors directly)
- Writes `/etc/mbpfan.conf` tuned for MacBook Air 2020 fan curve:
  - Below 55°C → 2700 RPM (near-silent)
  - 55–70°C → linear ramp to 4500 RPM
  - 70–85°C → ramp to 6500 RPM
  - Above 85°C → 8000 RPM (maximum)
- Writes `/etc/thermald/thermal-conf.xml` to limit `thermald` to Intel RAPL power capping only (no fan control)
- Enables and starts `mbpfan.service`

After running, monitor for 2 minutes:

```bash
watch -n 2 'sensors | grep -E "Package|fan1"'
```

Expected: temperatures should drop below 80°C within a few minutes and stabilise. Fan speed will rise to match load.

### Manual Fan Control (Emergency)

If temperatures are critical before running the script:

```bash
# Force fan to maximum speed immediately
echo 1 | sudo tee /sys/devices/platform/applesmc.768/fan1_manual
echo 8000 | sudo tee /sys/devices/platform/applesmc.768/fan1_output

# Return to automatic control
echo 0 | sudo tee /sys/devices/platform/applesmc.768/fan1_manual
```

---

## ⚙️ Post-Install: System Optimisation

```bash
# Run all optimisations (some sections require sudo)
sudo bash scripts/03-optimise.sh
```

### What Gets Optimised

**Kernel Parameters** — adds to `/etc/kernel/cmdline`:
- `intel_idle.max_cstate=4` — prevents deep C-states causing audio pops
- `snd_hda_intel.power_save=0` — T2 audio stability
- `pcie_aspm=off` — prevents PCIe conflicts with T2 bridge
- `mem_sleep_default=deep` — proper suspend behaviour

**sysctl** — writes `/etc/sysctl.d/99-macbook-air-2020.conf`:
- `vm.swappiness=10` — keeps data in RAM, ZRAM handles overflow
- `vm.vfs_cache_pressure=50` — retains filesystem cache longer
- BTRFS-friendly writeback tuning

**TLP** — writes `/etc/tlp.d/10-macbook-air-2020.conf`:
- Ice Lake CPU governor: `performance` on AC, `powersave` on battery
- Wi-Fi power management: **disabled** (BCM4377b disconnects under PM)
- USB autosuspend: **disabled** (T2 BCE bridge stability)
- T2 audio power save: **disabled** (prevents crackling)

**PipeWire** — writes `~/.config/pipewire/pipewire.conf.d/10-t2-macbook-audio.conf`:
- Increases quantum buffer size to reduce xruns with apple-bce driver
- 48kHz sample rate (matches T2 hardware default)

**Suspend / Resume**:
- Confirms `deep` sleep mode is active
- Installs `macbook-suspend-fix.service` — reloads `apple-bce` on resume to restore keyboard/trackpad if they freeze

### Power Management: TLP vs power-profiles-daemon

Both `tlp` and `power-profiles-daemon` are running on your system. They can conflict. Choose one:

```bash
# Option A — Keep TLP (recommended for developers)
sudo systemctl disable --now power-profiles-daemon

# Option B — Keep power-profiles-daemon (simpler, desktop-integrated)
sudo systemctl disable --now tlp
```

### Useful Commands

```bash
# Check temperatures
sensors

# Check power consumption (run on battery for ~5 min first)
sudo powertop

# Check NVMe health
sudo nvme smart-log /dev/nvme0n1

# Check CPU frequency scaling
cpupower frequency-info

# Check current power profile
powerprofilesctl get   # if using ppd

# TLP status
sudo tlp-stat -s
```

---

## 🔧 Hardware Status

| Hardware | Status | Notes |
|---|---|---|
| **Wi-Fi** (BCM4377b) | ✅ Working | `brcmfmac` driver, firmware in `/lib/firmware/brcm/` |
| **Bluetooth** (BRCM4377) | ✅ Working | `hci_bcm4377` driver |
| **Audio** (T2) | ✅ Working | `apple-bce` → PipeWire, built-in speakers + mic |
| **Keyboard / Trackpad** | ✅ Working | Via `apple-bce` USB-over-PCIe |
| **Touch ID** | ❌ Not supported | T2 Secure Enclave — Linux cannot access |
| **Graphics** (Iris Plus G7) | ✅ Working | `i915` driver, hardware acceleration available |
| **Display** | ✅ Working | Internal display full resolution |
| **Webcam** | ⚠️ Partial | May require `apple-bce` updates; check `v4l2-ctl --list-devices` |
| **Sleep / Wake** | ⚠️ Mostly working | Run `01-thermal-setup.sh` and `03-optimise.sh` for best results |
| **MagSafe / USB-C charging** | ✅ Working | Both USB-C ports charge |
| **Thunderbolt** | ⚠️ Limited | Basic USB-C works; Thunderbolt-specific features may not |
| **NVMe** | ✅ Working | Full speed; TRIM via `discard=async` |

---

## 🔐 Encrypted Code Vault (Optional)

A LUKS2-encrypted BTRFS loopback container for securing source code. This is separate from the main disk encryption.

### Creating the Vault

```bash
# 1. Create a raw image file (adjust size as needed)
fallocate -l 60G ~/.vault.img

# 2. Format as LUKS2 (you will be prompted to set a passphrase)
cryptsetup luksFormat --type luks2 ~/.vault.img

# 3. Open the container
sudo cryptsetup open ~/.vault.img code_vault

# 4. Format with BTRFS
sudo mkfs.btrfs -L CODE_REPOS /dev/mapper/code_vault

# 5. Create mount point and mount
mkdir -p ~/Code
sudo mount /dev/mapper/code_vault ~/Code

# 6. Take ownership
sudo chown -R $USER:$USER ~/Code
```

### Opening and Closing the Vault

```bash
# Open
sudo cryptsetup open ~/.vault.img code_vault
sudo mount /dev/mapper/code_vault ~/Code

# Close (unmount first)
sudo umount ~/Code
sudo cryptsetup close code_vault
```

### Automating with a Shell Alias

Add to your `~/.bashrc` or `~/.config/fish/config.fish`:

```bash
# bash / zsh
alias vault-open='sudo cryptsetup open ~/.vault.img code_vault && sudo mount /dev/mapper/code_vault ~/Code && sudo chown -R $USER:$USER ~/Code'
alias vault-close='sudo umount ~/Code && sudo cryptsetup close code_vault'
```

```fish
# fish
abbr vault-open 'sudo cryptsetup open ~/.vault.img code_vault && sudo mount /dev/mapper/code_vault ~/Code && sudo chown -R $USER:$USER ~/Code'
abbr vault-close 'sudo umount ~/Code && sudo cryptsetup close code_vault'
```

> **Note on `/etc/fstab`:** Because `~/.vault.img` lives inside your already-mounted home directory, do not add it to `/etc/fstab`. This causes boot delays and potential failures if the file is unavailable during early boot. Use the aliases above instead.

---

## 🛠 Troubleshooting

### CPU Running at 100°C

Run the thermal setup script immediately:

```bash
sudo bash scripts/01-thermal-setup.sh
```

Emergency fan override while that runs:
```bash
echo 1 | sudo tee /sys/devices/platform/applesmc.768/fan1_manual
echo 8000 | sudo tee /sys/devices/platform/applesmc.768/fan1_output
```

### Wi-Fi Not Working After Reinstall

```bash
sudo bash scripts/02-wifi-firmware.sh install-pkg
```

### Keyboard / Trackpad Frozen After Wake

```bash
sudo modprobe -r apple-bce && sudo modprobe apple-bce
```

To apply this automatically on every resume:
```bash
sudo bash scripts/03-optimise.sh  # installs macbook-suspend-fix.service
```

### Audio Crackling or Pops

```bash
# Apply the PipeWire buffer fix
bash scripts/03-optimise.sh --audio-only
systemctl --user restart pipewire pipewire-pulse

# If audio device disappears entirely, reload the BCE module
sudo modprobe -r snd_hda_intel apple-bce
sudo modprobe apple-bce snd_hda_intel
```

### Cannot Boot After Kernel Update

Hold **Space** at the Limine splash to access the snapshot menu. Boot the last known good snapshot, then investigate:

```bash
# Check which kernel is installed
pacman -Q linux-cachyos

# Downgrade if needed (from cache)
sudo pacman -U /var/cache/pacman/pkg/linux-cachyos-*.pkg.tar.zst
```

### macOS Won't Boot

Check boot order:
```bash
sudo efibootmgr

# Force macOS on next boot
sudo efibootmgr -n 0080
```

### Limine Not Showing Up

Boot from the CachyOS USB, mount your system, and reinstall Limine:
```bash
sudo mount /dev/nvme0n1p2 /mnt -o subvol=/@
sudo mount /dev/nvme0n1p1 /mnt/boot
sudo arch-chroot /mnt
limine-install /dev/nvme0n1
```

---

## 📚 References

- [CachyOS T2 MacBook Installation Wiki](https://wiki.cachyos.org/installation/installation_t2macbook/)
- [T2 Linux Project](https://t2linux.org)
- [t2linux Wi-Fi Firmware Guide](https://wiki.t2linux.org/guides/wifi-bluetooth/)
- [iFixit: Install Linux on a T2 Mac](https://www.ifixit.com/Guide/How+to+Install+Linux+on+a+T2+Mac/198407)
- [apple-bce kernel module](https://github.com/t2linux/apple-bce-drv)
- [mbpfan](https://github.com/linux-on-mac/mbpfan)
- [arch-mact2 firmware mirror](https://mirror.funami.tech/arch-mact2/)

---

## 📄 Licence

MIT — see [LICENSE](LICENSE).

Configurations and scripts are based on field testing on a MacBook Air 2020 (MacBookAir9,1) running CachyOS with kernel 6.19.x. Your mileage may vary on other hardware revisions.
