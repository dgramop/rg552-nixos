# RG552 SD Card Image Layout

This document describes the SD card layout required to boot the Anbernic RG552 (RK3399 SoC).

## Overview

The RG552 uses the Rockchip RK3399 SoC which requires a specific boot sequence with bootloader components placed at precise offsets on the storage device.

## Physical Layout

```
┌─────────────────────────────────────────────────────────────┐
│ Sector 0                                                     │
│ MBR / GPT Header                                             │
│ (32 KB / 64 sectors)                                         │
├─────────────────────────────────────────────────────────────┤
│ Sector 64 (0x40)                                             │
│ Offset: 32 KB (0x8000)                                       │
│                                                              │
│ U-Boot Bootloader (u-boot-rockchip.bin)                     │
│                                                              │
│ Contains:                                                    │
│   - idbloader.img (DDR init + miniloader)                   │
│   - u-boot.img (U-Boot proper)                              │
│   - trust.img (ARM Trusted Firmware BL31)                   │
│                                                              │
│ Size: ~8-16 MB                                               │
├─────────────────────────────────────────────────────────────┤
│ Sector 32768 (0x8000)                                        │
│ Offset: 16 MB (0x1000000)                                    │
│                                                              │
│ PARTITION 1: SYSTEM (FAT32)                                 │
│ Label: SYSTEM                                                │
│ Size: 2048 MB (default, configurable)                       │
│ Flags: boot                                                  │
│                                                              │
│ Contents:                                                    │
│   /KERNEL                      - ARM64 Linux kernel Image    │
│   /SYSTEM                      - Root filesystem (squashfs)  │
│   /device_trees/               - Device tree binaries        │
│     rk3399-anbernic-rg552.dtb                                │
│   /extlinux/                   - Boot configuration          │
│     extlinux.conf              - Bootloader menu config      │
│   /overlays/                   - Device tree overlays (opt)  │
│                                                              │
├─────────────────────────────────────────────────────────────┤
│ After System Partition                                       │
│                                                              │
│ PARTITION 2: STORAGE (ext4)                                 │
│ Label: STORAGE                                               │
│ Size: Remaining space (typically 32+ GB)                     │
│                                                              │
│ Contents:                                                    │
│   User data and application storage                          │
│   (games, saves, configurations)                             │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Sector and Offset Reference

| Component | Sector | Byte Offset | Size | Description |
|-----------|--------|-------------|------|-------------|
| **MBR/GPT** | 0-63 | 0x0 - 0x7FFF | 32 KB | Partition table |
| **Bootloader** | 64+ | 0x8000+ | ~8-16 MB | u-boot-rockchip.bin |
| **System Partition** | 32768+ | 0x1000000+ | 2048 MB | FAT32 boot partition |
| **Storage Partition** | Varies | Varies | Remaining | ext4 user data |

**Note**: All sectors are 512 bytes.

## Boot Sequence

1. **ROM Boot** (built into SoC)
   - RK3399 internal ROM code runs on power-on
   - Searches for bootloader at sector 64 (32 KB offset)
   - Loads and executes initial bootloader (idbloader)

2. **idbloader.img** (loaded from sector 64)
   - Contains DDR initialization firmware
   - Contains miniloader (Rockchip proprietary loader)
   - Initializes RAM and basic hardware
   - Loads next stage from fixed offset

3. **U-Boot** (loaded by idbloader)
   - Full-featured bootloader
   - Reads extlinux.conf from FAT32 partition
   - Loads kernel and device tree
   - Passes control to Linux kernel

4. **Linux Kernel**
   - Kernel Image loaded from /KERNEL
   - Device tree from /device_trees/rk3399-anbernic-rg552.dtb
   - Mounts root filesystem from /SYSTEM or partition 2

## Bootloader Components

The bootloader blob `u-boot-rockchip.bin` is a composite image containing:

### Internal Layout of u-boot-rockchip.bin

```
Offset (sectors)  Component         Source Files
─────────────────────────────────────────────────────────
0                 idbloader.img     - rk3399_ddr_933MHz_v1.30.bin (DDR firmware)
                                    - rk3399_miniloader_v1.30.bin (miniloader)

16320             u-boot.img        - u-boot-dtb.bin (U-Boot + DTB)
                                    (built from evb-rk3399_defconfig)

24512             trust.img         - bl31.elf (ARM Trusted Firmware)
                                    (merged using RK3399TRUST.ini)
```

### Building u-boot-rockchip.bin

From ROCKNIX build system (`rkhelper` script):

```bash
# 1. Create idbloader.img
mkimage -n rk3399 -T rksd \
    -d rk3399_ddr_933MHz_v1.30.bin:rk3399_miniloader_v1.30.bin \
    -C bzip2 idbloader.img

# 2. Pack U-Boot image
loaderimage --pack --uboot u-boot-dtb.bin uboot.img 0x00200000

# 3. Merge ARM Trusted Firmware
trust_merger --ignore-bl32 --prepath rkbin/ RK3399TRUST.ini

# 4. Combine into single bootloader
dd if=idbloader.img of=uboot.bin bs=512 seek=0 conv=fsync,notrunc
dd if=uboot.img of=uboot.bin bs=512 seek=16320 conv=fsync,notrunc
dd if=trust.img of=uboot.bin bs=512 seek=24512 conv=fsync,notrunc

# Result: uboot.bin (renamed to u-boot-rockchip.bin)
```

## extlinux.conf Format

Located at `/extlinux/extlinux.conf` on the FAT32 system partition:

```
LABEL RG552
  LINUX /KERNEL
  FDT /device_trees/rk3399-anbernic-rg552.dtb
  APPEND root=/dev/mmcblk0p2 rootwait ro console=tty1 console=ttyS2,1500000n8
```

Parameters:
- `LINUX`: Path to kernel image (relative to partition root)
- `FDT`: Path to device tree blob
- `APPEND`: Kernel command line arguments
  - `root=/dev/mmcblk0p2`: Root filesystem location
  - `rootwait`: Wait for root device to appear
  - `ro`: Mount root read-only initially
  - `console=tty1`: Output to display
  - `console=ttyS2,1500000n8`: Serial console (UART2, 1.5 Mbaud)

## Partition Table Format

**Type**: GPT (GUID Partition Table)

**Alignment**: Minimum alignment (no padding)

**Partitions**:
1. System (FAT32, bootable)
   - Start: Sector 32768 (16 MB)
   - Size: 2048 MB (default)
   - UUID: Auto-generated

2. Storage (ext4)
   - Start: End of partition 1 + 1
   - Size: Remaining space
   - UUID: Auto-generated

## Device Tree

**File**: `rk3399-anbernic-rg552.dtb`

**Source**: Linux kernel device tree compiled from `rk3399-anbernic-rg552.dts`

**Key Hardware Definitions**:
- CPU: RK3399 (2x Cortex-A72 + 4x Cortex-A53)
- Display: Sharp LS054B3SX01 (1152x1920 MIPI DSI)
- Audio: ES8316 codec (I2S)
- Battery: CW2015 fuel gauge (6400mAh Li-Po)
- Storage: eMMC (sdhci), MicroSD (sdmmc)
- USB: Type-C with PD (FUSB302)
- Controls: GPIO buttons + ADC joysticks
- Serial: UART2 @ 1.5 Mbaud

## Flashing Process

1. **Write bootloader** to sector 64:
   ```bash
   dd if=u-boot-rockchip.bin of=/dev/sdX bs=512 seek=64 conv=fsync,notrunc
   ```

2. **Create GPT partition table**:
   ```bash
   parted -s /dev/sdX mklabel gpt
   parted -s /dev/sdX -a min unit s mkpart system fat32 32768 4226047
   parted -s /dev/sdX -a min unit s mkpart storage ext4 4226048 100%
   parted -s /dev/sdX set 1 boot on
   ```

3. **Format partitions**:
   ```bash
   mkfs.vfat -F 32 -n SYSTEM /dev/sdX1
   mkfs.ext4 -L STORAGE /dev/sdX2
   ```

4. **Install boot files** to system partition:
   ```bash
   mount /dev/sdX1 /mnt
   cp KERNEL /mnt/
   cp SYSTEM /mnt/  # optional: squashfs root
   mkdir -p /mnt/device_trees
   cp rk3399-anbernic-rg552.dtb /mnt/device_trees/
   mkdir -p /mnt/extlinux
   cat > /mnt/extlinux/extlinux.conf << EOF
   LABEL RG552
     LINUX /KERNEL
     FDT /device_trees/rk3399-anbernic-rg552.dtb
     APPEND root=/dev/mmcblk0p2 rootwait ro console=tty1 console=ttyS2,1500000n8
   EOF
   sync
   umount /mnt
   ```

## Critical Requirements

1. **Bootloader must be at sector 64** (32 KB offset)
   - RK3399 ROM code searches this exact location
   - Incorrect placement = no boot

2. **System partition must be FAT32**
   - U-Boot expects FAT32 for boot files
   - Must contain extlinux.conf

3. **GPT partition table required**
   - Bootloader expects GPT, not MBR
   - MBR compatibility mode not supported

4. **Serial console required for debugging**
   - UART2 on GPIO header
   - 1.5 Mbaud (non-standard baud rate)
   - Add to kernel command line for output

## Sources

- ROCKNIX Distribution: https://github.com/ROCKNIX/distribution
- Pine64 RK3399 Boot Sequence: https://wiki.pine64.org/wiki/RK3399_boot_sequence
- Rockchip U-Boot: https://github.com/rockchip-linux/u-boot
- RK3399 Technical Reference Manual (Rockchip)
