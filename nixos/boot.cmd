# U-Boot boot script to fix memory overlap issue
# The default ramdisk_addr_r conflicts with the large NixOS kernel
# Move initrd load address to 0x10000000 (256MB) to avoid overlap

# Set memory addresses for boot
# kernel_addr_r:  0x02080000 (default, where kernel is decompressed)
# ramdisk_addr_r: 0x10000000 (256MB - moved higher to avoid overlap)
# fdt_addr_r:     0x01f00000 (default, device tree)

setenv ramdisk_addr_r 0x10000000

# Initialize SD card (device 1)
# Device 0 is eMMC, device 1 is SD card
# Note: Cannot use "mmc dev 1 1" - partition selection doesn't work
# Partition is specified in load commands as "mmc 1:1"
mmc dev 1

# Manually load kernel, initrd, and device tree from SD card
echo "Loading kernel from /Image..."
load mmc 1:1 ${kernel_addr_r} /Image

echo "Loading initrd from /initrd..."
load mmc 1:1 ${ramdisk_addr_r} /initrd
setenv ramdisk_size ${filesize}

echo "Loading device tree from /device_trees/rk3399-anbernic-rg552.dtb..."
load mmc 1:1 ${fdt_addr_r} /device_trees/rk3399-anbernic-rg552.dtb

# Set boot arguments
# Note: @INIT@ will be replaced with full kernel parameters by sed substitution
setenv bootargs "@INIT@"

# Boot the kernel
echo "Booting NixOS kernel..."
booti ${kernel_addr_r} ${ramdisk_addr_r}:${ramdisk_size} ${fdt_addr_r}
