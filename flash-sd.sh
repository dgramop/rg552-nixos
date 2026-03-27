#!/usr/bin/env bash
set -euo pipefail

# Minimal RG552 SD Card Flasher
# Based on ROCKNIX bootloader layout for RK3399

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] <device>

Flash a bootable SD card for Anbernic RG552 (RK3399)

OPTIONS:
    -b, --bootloader FILE   Path to u-boot-rockchip.bin (required)
    -k, --kernel FILE       Path to kernel Image (required)
    -d, --dtb FILE          Path to rk3399-anbernic-rg552.dtb (required)
    -r, --rootfs FILE       Path to root filesystem image (optional)
    -s, --system-size MB    System partition size in MB (default: 2048)
    -h, --help              Show this help

EXAMPLE:
    $0 -b u-boot-rockchip.bin -k Image -d rk3399-anbernic-rg552.dtb /dev/sdX

DEVICE:
    Block device to flash (e.g., /dev/sdb, /dev/mmcblk0)
    WARNING: This will DESTROY all data on the device!

BOOT LAYOUT:
    Sector 0-63:      MBR/GPT header (32KB)
    Sector 64:        U-Boot bootloader (starts at 32KB offset)
    Sector 32768:     System partition (FAT32) - kernel, dtb, bootloader config
    After system:     Storage partition (ext4) - user data

EOF
    exit 1
}

# Parse arguments
BOOTLOADER=""
KERNEL=""
DTB=""
ROOTFS=""
SYSTEM_SIZE=2048
DEVICE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--bootloader)
            BOOTLOADER="$2"
            shift 2
            ;;
        -k|--kernel)
            KERNEL="$2"
            shift 2
            ;;
        -d|--dtb)
            DTB="$2"
            shift 2
            ;;
        -r|--rootfs)
            ROOTFS="$2"
            shift 2
            ;;
        -s|--system-size)
            SYSTEM_SIZE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        -*)
            echo "Unknown option: $1"
            usage
            ;;
        *)
            DEVICE="$1"
            shift
            ;;
    esac
done

# Validate required arguments
if [[ -z "$DEVICE" ]]; then
    echo "ERROR: Device not specified"
    usage
fi

if [[ -z "$BOOTLOADER" ]]; then
    echo "ERROR: Bootloader file not specified (-b/--bootloader)"
    usage
fi

if [[ -z "$KERNEL" ]]; then
    echo "ERROR: Kernel file not specified (-k/--kernel)"
    usage
fi

if [[ -z "$DTB" ]]; then
    echo "ERROR: Device tree file not specified (-d/--dtb)"
    usage
fi

# Validate files exist
for file in "$BOOTLOADER" "$KERNEL" "$DTB"; do
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file"
        exit 1
    fi
done

if [[ -n "$ROOTFS" ]] && [[ ! -f "$ROOTFS" ]]; then
    echo "ERROR: Root filesystem not found: $ROOTFS"
    exit 1
fi

# Validate device
if [[ ! -b "$DEVICE" ]]; then
    echo "ERROR: Device not found or not a block device: $DEVICE"
    exit 1
fi

# Safety check
echo "WARNING: This will DESTROY all data on $DEVICE"
echo "Press Ctrl+C to abort, or Enter to continue..."
read -r

echo "==> Unmounting any existing partitions on $DEVICE"
umount "${DEVICE}"* 2>/dev/null || true

echo "==> Wiping partition table"
dd if=/dev/zero of="$DEVICE" bs=1M count=16 conv=fsync

echo "==> Creating GPT partition table"
parted -s "$DEVICE" mklabel gpt

# Calculate partition boundaries (in sectors, 512 bytes each)
SYSTEM_PART_START=32768  # 16MB offset
SYSTEM_SIZE_SECTORS=$((SYSTEM_SIZE * 1024 * 1024 / 512))
SYSTEM_PART_END=$((SYSTEM_PART_START + SYSTEM_SIZE_SECTORS - 1))
STORAGE_PART_START=$((SYSTEM_PART_END + 1))

echo "==> Creating system partition (FAT32, ${SYSTEM_SIZE}MB)"
parted -s "$DEVICE" -a min unit s mkpart system fat32 $SYSTEM_PART_START $SYSTEM_PART_END

echo "==> Creating storage partition (ext4, remaining space)"
parted -s "$DEVICE" -a min unit s mkpart storage ext4 $STORAGE_PART_START 100%

echo "==> Setting partition flags"
parted -s "$DEVICE" set 1 boot on

# Determine partition device names
if [[ "$DEVICE" =~ mmcblk|loop ]]; then
    PART1="${DEVICE}p1"
    PART2="${DEVICE}p2"
else
    PART1="${DEVICE}1"
    PART2="${DEVICE}2"
fi

echo "==> Waiting for partition devices to appear"
sleep 2
partprobe "$DEVICE" 2>/dev/null || true
sleep 1

echo "==> Formatting system partition (FAT32)"
mkfs.vfat -F 32 -n "SYSTEM" "$PART1"

echo "==> Formatting storage partition (ext4)"
mkfs.ext4 -F -L "STORAGE" "$PART2"

echo "==> Writing bootloader at 32KB offset (sector 64)"
dd if="$BOOTLOADER" of="$DEVICE" bs=512 seek=64 conv=fsync,notrunc

echo "==> Mounting system partition"
MOUNT_POINT=$(mktemp -d)
trap "umount '$MOUNT_POINT' 2>/dev/null || true; rmdir '$MOUNT_POINT'" EXIT
mount "$PART1" "$MOUNT_POINT"

echo "==> Installing kernel"
cp "$KERNEL" "$MOUNT_POINT/KERNEL"

echo "==> Installing device tree"
mkdir -p "$MOUNT_POINT/device_trees"
cp "$DTB" "$MOUNT_POINT/device_trees/"
DTB_NAME=$(basename "$DTB")

echo "==> Creating extlinux boot configuration"
mkdir -p "$MOUNT_POINT/extlinux"
cat > "$MOUNT_POINT/extlinux/extlinux.conf" <<EOF_EXTLINUX
LABEL RG552
  LINUX /KERNEL
  FDT /device_trees/${DTB_NAME}
  APPEND root=/dev/mmcblk0p2 rootwait ro console=tty1 console=ttyS2,1500000n8
EOF_EXTLINUX

# Copy rootfs if provided
if [[ -n "$ROOTFS" ]]; then
    echo "==> Installing root filesystem"
    cp "$ROOTFS" "$MOUNT_POINT/SYSTEM"
fi

echo "==> Syncing filesystems"
sync

echo "==> Unmounting"
umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"
trap - EXIT

echo ""
echo "==> SUCCESS! SD card is ready."
echo ""
echo "Partition layout:"
parted -s "$DEVICE" print
echo ""
echo "You can now insert the SD card into your RG552 and power it on."
echo "The device should attempt to boot from the SD card."
