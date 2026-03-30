# U-Boot boot script to fix memory overlap issue
# The default ramdisk_addr_r conflicts with the large NixOS kernel
# Move initrd load address to 0x10000000 (256MB) to avoid overlap

# Set memory addresses for boot
# kernel_addr_r:  0x02080000 (default, where kernel is decompressed)
# ramdisk_addr_r: 0x10000000 (256MB - moved higher to avoid overlap)
# fdt_addr_r:     0x01f00000 (default, device tree)

setenv ramdisk_addr_r 0x10000000

# Initialize MMC device and select partition 1
mmc dev 0 1

# Manually load kernel, initrd, and device tree
echo "Loading kernel from /Image..."
load mmc 0:1 ${kernel_addr_r} /Image

echo "Loading initrd from /initrd..."
load mmc 0:1 ${ramdisk_addr_r} /initrd
setenv ramdisk_size ${filesize}

echo "Loading device tree from /device_trees/rk3399-anbernic-rg552.dtb..."
load mmc 0:1 ${fdt_addr_r} /device_trees/rk3399-anbernic-rg552.dtb

# Set boot arguments
setenv bootargs "init=@INIT@ earlycon=uart8250,mmio32,0xff1a0000,1500000n8 console=tty1 console=ttyS2,1500000n8 rootwait loglevel=7 systemd.log_level=debug systemd.log_target=console rd.debug"

# Boot the kernel
echo "Booting NixOS kernel..."
booti ${kernel_addr_r} ${ramdisk_addr_r}:${ramdisk_size} ${fdt_addr_r}
