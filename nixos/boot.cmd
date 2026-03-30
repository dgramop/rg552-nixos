# U-Boot boot script to fix memory overlap issue
# The default ramdisk_addr_r conflicts with the large NixOS kernel
# Move initrd load address to 0x10000000 (256MB) to avoid overlap

# Set memory addresses for boot
# kernel_addr_r:  0x02080000 (default, where kernel is decompressed)
# ramdisk_addr_r: 0x10000000 (256MB - moved higher to avoid overlap)
# fdt_addr_r:     0x01f00000 (default, device tree)

setenv ramdisk_addr_r 0x10000000

# Continue with standard extlinux boot
sysboot mmc 0:1 any ${scriptaddr} /extlinux/extlinux.conf
