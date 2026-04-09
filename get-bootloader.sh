#!/usr/bin/env bash
set -euo pipefail

# RG552 Bootloader Extraction Helper
# Extracts u-boot-rockchip.bin from ROCKNIX build or downloads prebuilt

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    cat <<EOF
Usage: $0 [OPTIONS]

Extract or download bootloader for RG552 (RK3399)

OPTIONS:
    -r, --rocknix-dir DIR   Path to ROCKNIX distribution checkout
    -d, --download          Download prebuilt bootloader from ROCKNIX releases
    -o, --output FILE       Output path for bootloader (default: ./u-boot-rockchip.bin)
    -h, --help              Show this help

METHODS:
    1. Extract from ROCKNIX build directory (if built)
    2. Download from ROCKNIX release images
    3. Build from source (future)

EXAMPLES:
    # Extract from ROCKNIX build
    $0 --rocknix-dir /tmp/rocknix

    # Download prebuilt from release
    $0 --download

    # Specify output location
    $0 --download --output bootloader/u-boot-rockchip.bin

BOOTLOADER INFO:
    The bootloader is a combined image containing:
    - idbloader.img (DDR init + miniloader)
    - u-boot.img (U-Boot proper with evb-rk3399_defconfig)
    - trust.img (ARM Trusted Firmware BL31)

    Must be written to SD card at sector 64 (32KB offset).

EOF
    exit 1
}

# Parse arguments
ROCKNIX_DIR=""
DOWNLOAD=false
OUTPUT="$SCRIPT_DIR/u-boot-rockchip.bin"

while [[ $# -gt 0 ]]; do
    case $1 in
        -r|--rocknix-dir)
            ROCKNIX_DIR="$2"
            shift 2
            ;;
        -d|--download)
            DOWNLOAD=true
            shift
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Method 1: Extract from ROCKNIX build
extract_from_build() {
    local rocknix_dir="$1"
    local output="$2"

    if [[ ! -d "$rocknix_dir" ]]; then
        echo "ERROR: ROCKNIX directory not found: $rocknix_dir"
        return 1
    fi

    # Look for built bootloader in common locations
    local search_paths=(
        "$rocknix_dir/build.ROCKNIX-RK3399.aarch64/u-boot-*/u-boot-rockchip.bin"
        "$rocknix_dir/build.ROCKNIX-RK3399.aarch64/u-boot-*/uboot.bin"
        "$rocknix_dir/release/*/u-boot-rockchip.bin"
        "$rocknix_dir/target/u-boot-rockchip.bin"
    )

    echo "==> Searching for bootloader in ROCKNIX build directory..."
    for pattern in "${search_paths[@]}"; do
        # Use nullglob to handle no matches gracefully
        shopt -s nullglob
        for file in $pattern; do
            if [[ -f "$file" ]]; then
                echo "==> Found: $file"
                cp "$file" "$output"
                local size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
                echo "==> Extracted bootloader: $output ($(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo $size bytes))"
                return 0
            fi
        done
        shopt -u nullglob
    done

    echo "ERROR: Bootloader not found in ROCKNIX build directory"
    echo "Have you built ROCKNIX? Try: cd $rocknix_dir && PROJECT=ROCKNIX DEVICE=RK3399 ARCH=aarch64 make u-boot"
    return 1
}

# Method 2: Download from ROCKNIX release
download_prebuilt() {
    local output="$1"

    echo "==> Downloading bootloader from ROCKNIX release..."
    echo ""
    echo "NOTE: ROCKNIX releases are full system images (.img.gz files)."
    echo "To extract just the bootloader from a release image:"
    echo ""
    echo "1. Download a RK3399 release from:"
    echo "   https://github.com/ROCKNIX/distribution/releases"
    echo ""
    echo "2. Extract bootloader from the image:"
    echo "   gunzip -c ROCKNIX-RK3399-*.img.gz | dd bs=512 skip=64 count=32704 of=u-boot-rockchip.bin"
    echo ""
    echo "   This extracts sectors 64-32767 (bootloader region, ~16MB)"
    echo ""
    echo "Alternatively, build ROCKNIX from source:"
    echo "   git clone https://github.com/ROCKNIX/distribution"
    echo "   cd distribution"
    echo "   PROJECT=ROCKNIX DEVICE=RK3399 ARCH=aarch64 make u-boot"
    echo "   Then run: $0 --rocknix-dir . --output $output"
    echo ""

    # Check if we can download via GitHub API
    if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
        echo "==> Fetching latest release info from GitHub..."
        local latest_url=$(curl -s https://api.github.com/repos/ROCKNIX/distribution/releases/latest | \
                          jq -r '.assets[] | select(.name | contains("RK3399") and endswith(".img.gz")) | .browser_download_url' | \
                          head -1)

        if [[ -n "$latest_url" ]]; then
            echo "==> Latest RK3399 image: $latest_url"
            echo ""
            read -p "Download and extract bootloader? This may take several minutes and ~500MB+ download. [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                local temp_img=$(mktemp -u).img.gz
                echo "==> Downloading release image to $temp_img..."
                curl -L --progress-bar "$latest_url" -o "$temp_img"

                echo "==> Extracting bootloader from image..."
                gunzip -c "$temp_img" | dd bs=512 skip=64 count=32704 of="$output" 2>/dev/null

                echo "==> Cleaning up temporary files..."
                rm -f "$temp_img"

                local size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null)
                echo "==> Extracted bootloader: $output ($(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo $size bytes))"
                return 0
            else
                echo "Download cancelled."
                return 1
            fi
        fi
    fi

    return 1
}

# Main execution
main() {
    if [[ $DOWNLOAD == true ]]; then
        download_prebuilt "$OUTPUT" || exit 1
    elif [[ -n "$ROCKNIX_DIR" ]]; then
        extract_from_build "$ROCKNIX_DIR" "$OUTPUT" || exit 1
    else
        echo "ERROR: Must specify either --download or --rocknix-dir"
        echo ""
        usage
    fi

    # Verify output
    if [[ -f "$OUTPUT" ]]; then
        local size=$(stat -f%z "$OUTPUT" 2>/dev/null || stat -c%s "$OUTPUT" 2>/dev/null)
        echo ""
        echo "SUCCESS! Bootloader ready:"
        echo "  Location: $OUTPUT"
        echo "  Size: $(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo $size bytes)"
        echo ""
        echo "Next: place it at nixos/u-boot-rockchip.bin and run 'nix build' to produce the SD image."
        echo ""
        return 0
    else
        echo "ERROR: Failed to create bootloader file"
        return 1
    fi
}

main
