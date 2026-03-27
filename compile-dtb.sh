#!/usr/bin/env bash
set -euo pipefail

# Compile device tree for RG552
# Requires Linux kernel source tree for includes

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DTS_FILE="$SCRIPT_DIR/rk3399-anbernic-rg552.dts"
DTB_FILE="$SCRIPT_DIR/rk3399-anbernic-rg552.dtb"

if [[ ! -f "$DTS_FILE" ]]; then
    echo "ERROR: Device tree source not found: $DTS_FILE"
    exit 1
fi

# Check if we have a Linux kernel tree
KERNEL_SRC="${KERNEL_SRC:-}"

if [[ -z "$KERNEL_SRC" ]]; then
    # Try to find kernel source in common locations
    for path in \
        /lib/modules/$(uname -r)/build \
        /usr/src/linux \
        /usr/src/linux-headers-$(uname -r) \
        ~/linux \
        /tmp/linux-kernel
    do
        if [[ -f "$path/arch/arm64/boot/dts/rockchip/rk3399.dtsi" ]]; then
            KERNEL_SRC="$path"
            break
        fi
    done
fi

if [[ -z "$KERNEL_SRC" ]] || [[ ! -d "$KERNEL_SRC" ]]; then
    echo "ERROR: Linux kernel source not found."
    echo ""
    echo "The device tree requires kernel headers for includes."
    echo ""
    echo "Option 1: Set KERNEL_SRC environment variable:"
    echo "  KERNEL_SRC=/path/to/linux $0"
    echo ""
    echo "Option 2: Clone kernel source:"
    echo "  git clone --depth 1 --branch v6.12 \\"
    echo "    https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git /tmp/linux-kernel"
    echo "  KERNEL_SRC=/tmp/linux-kernel $0"
    echo ""
    echo "Option 3: Use NixOS server (if you have one):"
    echo "  ssh server 'cd /tmp && git clone --depth 1 --branch v6.12 \\"
    echo "    https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git linux-kernel'"
    echo "  scp $DTS_FILE server:/tmp/linux-kernel/arch/arm64/boot/dts/rockchip/"
    echo "  ssh server 'cd /tmp/linux-kernel && make dtbs ARCH=arm64'"
    echo "  scp server:/tmp/linux-kernel/arch/arm64/boot/dts/rockchip/rk3399-anbernic-rg552.dtb $DTB_FILE"
    exit 1
fi

DTS_DIR="$KERNEL_SRC/arch/arm64/boot/dts/rockchip"

echo "==> Using kernel source: $KERNEL_SRC"
echo "==> Copying device tree source to kernel tree..."
cp "$DTS_FILE" "$DTS_DIR/"

echo "==> Compiling device tree..."
cd "$KERNEL_SRC"

if command -v make >/dev/null 2>&1; then
    # Use kernel build system if available
    make ARCH=arm64 dtbs_check DT_SCHEMA_FILES=rockchip/rk3399-anbernic-rg552.yaml || true
    make ARCH=arm64 rockchip/rk3399-anbernic-rg552.dtb
    cp arch/arm64/boot/dts/rockchip/rk3399-anbernic-rg552.dtb "$DTB_FILE"
else
    # Fallback to dtc directly
    cd "$DTS_DIR"
    dtc -I dts -O dtb -o "$DTB_FILE" rk3399-anbernic-rg552.dts \
        -i . -i ../../..
fi

echo ""
echo "==> Success!"
ls -lh "$DTB_FILE"
echo ""
echo "Device tree compiled: $DTB_FILE"
