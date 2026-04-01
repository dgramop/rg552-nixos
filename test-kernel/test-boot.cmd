# U-Boot boot script for bare-metal test kernel
# This script loads and boots the minimal test kernel to verify U-Boot booti works

# Initialize SD card (device 1)
mmc dev 1

# Load test kernel from SD card
echo "==================================="
echo "Loading test kernel from /test-kernel..."
echo "==================================="
load mmc 1:1 ${kernel_addr_r} /test-kernel

# Load device tree (test kernel doesn't use it, but booti requires it)
echo "Loading device tree..."
load mmc 1:1 ${fdt_addr_r} /device_trees/rk3399-anbernic-rg552.dtb

# Print memory addresses
echo ""
echo "==================================="
echo "Memory layout:"
echo "==================================="
echo "kernel_addr_r  = ${kernel_addr_r}"
echo "fdt_addr_r     = ${fdt_addr_r}"
echo ""
echo "==================================="
echo "Booting test kernel..."
echo "==================================="
echo "If you see a test message, U-Boot booti works!"
echo "If not, the problem is with U-Boot or hardware."
echo ""

# Boot the test kernel (no initrd needed - pass "-" for initrd address)
booti ${kernel_addr_r} - ${fdt_addr_r}
