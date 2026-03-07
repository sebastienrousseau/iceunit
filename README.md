# CachyOS on MacBook Air 2020 (Intel)

A step-by-step guide to reproducing a fully functional CachyOS installation on a 2020 Intel MacBook Air. This setup serves as a stable, optimized Linux environment for cross-platform development.

### 💻 System Specifications & Target Hardware

| Component | Specification | Driver / Module |
| :--- | :--- | :--- |
| **Model** | Apple MacBook Air 2020 (MacBookAir9,1) | N/A |
| **OS** | CachyOS | N/A |
| **Kernel** | 6.19.5-3-cachyos | N/A |
| **CPU** | Intel Core i5-1030NG7 @ 1.10GHz | N/A |
| **Graphics** | Intel Iris Plus Graphics G7 (Ice Lake) | `i915` |
| **Security/Audio** | Apple T2 Bridge & Secure Enclave | `apple-bce` |
| **Wi-Fi** | Broadcom BCM4377b | `brcmfmac` |
| **Bluetooth** | Broadcom BRCM4377 | `hci_bcm4377` |

## 🔓 Pre-Installation: Bypassing the Apple T2 Security Chip

Apple's T2 Security Chip actively prevents booting from external USBs and running unverified operating systems by default. You must disable these protections from within macOS before attempting to boot the CachyOS installer.

### 1. Adjust Startup Security Settings
1. Shut down your MacBook completely.
2. Turn it on and immediately press and hold **Command (⌘) + R** to boot into macOS Recovery mode.
3. If prompted, select your administrator account and enter your macOS password.
4. In the top menu bar, click **Utilities** > **Startup Security Utility**.
5. Authenticate again if asked, then apply the following settings:
   - **Secure Boot:** Select **No Security**.
   - **Allowed Boot Media:** Select **Allow booting from external or removable media**.
6. Close the utility and shut down the Mac.

### 2. Boot the CachyOS USB
1. Insert your prepared CachyOS bootable USB flash drive.
2. Turn on the Mac and immediately press and hold the **Option (⌥)** key.
3. Keep holding until the Startup Manager appears.
4. Select the yellow external drive icon (often labeled "EFI Boot" or similar) and press **Enter**.

## 💽 Step 2: Disk Partitioning & LUKS Vault

This environment uses a highly specific partition layout: a BTRFS root for seamless system snapshots, ZRAM for performance, and a dedicated LUKS2-encrypted loopback file for securing cross-platform source code.

### 1. Base System Partitions (via CachyOS Calamares Installer)
When prompted by the CachyOS installer, select **Manual Partitioning**. Configure your internal NVMe drive (`nvme0n1`) as follows:

* **Partition 1 (`/boot`):** ~4GB, `fat32`. 
  * Mount point: `/boot/efi` (or `/boot` depending on the bootloader chosen).
  * Flags: `boot`, `esp`.
* **Partition 2 (`/`):** Remaining space (~250GB), `btrfs`. 
  * Mount point: `/`.
  * *Note:* The installer will automatically handle the standard BTRFS subvolumes (`@`, `@home`, `@var`, etc.).

*Do not create a dedicated swap partition. This setup relies entirely on **ZRAM** (`zram0`) to reduce wear on the NVMe drive.*

### 2. Post-Install: The Encrypted Vault
Once the base OS is installed and booted, the final storage step is creating the encrypted loopback container (`loop0`) mounted within your home directory (e.g., `/home/<your_username>/<vault_name>`).


