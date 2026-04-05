# RG552 NixOS Support

Boot NixOS on the Anbernic RG552 handheld gaming device (RK3399 SoC).

## Quick Start

### 1. Get the Bootloader

The RG552 requires a special bootloader (`u-boot-rockchip.bin`) to boot from SD card.

**Option A: Download from ROCKNIX release**
```bash
./get-bootloader.sh --download --output nixos/u-boot-rockchip.bin
```

**Option B: Extract from ROCKNIX build**
```bash
# Clone and build ROCKNIX (takes ~1-2 hours)
git clone https://github.com/ROCKNIX/distribution /tmp/rocknix
cd /tmp/rocknix
PROJECT=ROCKNIX DEVICE=RK3399 ARCH=aarch64 make u-boot

# Extract bootloader
cd -
./get-bootloader.sh --rocknix-dir /tmp/rocknix --output nixos/u-boot-rockchip.bin
```

### 2. Compile the Device Tree

The device tree source (`rk3399-anbernic-rg552.dts`) is already extracted from ROCKNIX.

```bash
# Install device tree compiler if needed
nix-shell -p dtc

# Compile device tree
dtc -I dts -O dtb -o rk3399-anbernic-rg552.dtb rk3399-anbernic-rg552.dts
```

### 3. Build the NixOS SD Image

```bash
cd nixos

# Build the SD image (requires aarch64 build support)
# On x86_64 machine with binfmt:
nix-build '<nixpkgs/nixos>' \
  -A config.system.build.sdImage \
  -I nixos-config=./configuration.nix \
  --argstr system aarch64-linux

# Or if you're on aarch64 already:
nixos-rebuild build-vm-with-bootloader -I nixos-config=./configuration.nix
```

**Using flakes:**
```bash
# Create a flake.nix first, then:
nix build .#nixosConfigurations.rg552.config.system.build.sdImage
```

### 4. Flash to SD Card

```bash
# Decompress image if needed
gunzip result/sd-image/*.img.gz

# Write the complete image
sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### 5. Boot the RG552

1. Insert SD card into RG552
2. Power on the device
3. It should boot NixOS!

## Files

- **get-bootloader.sh** - Extract/download bootloader from ROCKNIX
- **SD_CARD_LAYOUT.md** - Technical documentation of boot layout
- **flake.nix** - Nix flake for building SD images and kernel
- **nixos/** - NixOS configuration and kernel build files

## NixOS Module Structure

```
nixos/
├── sd-image-rg552.nix     # SD image builder module
├── configuration.nix       # Example NixOS config
└── u-boot-rockchip.bin    # Bootloader (you need to extract)
```

## Hardware Support Status

| Component | Status | Notes |
|-----------|--------|-------|
| **CPU** | ✅ Working | RK3399 (2xA72 + 4xA53) |
| **Display** | ⚠️ Untested | Sharp LS054B3SX01 (1152x1920 MIPI DSI) |
| **GPU** | ⚠️ Untested | Mali-T860MP4 (Panfrost driver) |
| **Audio** | ⚠️ Untested | ES8316 codec |
| **WiFi/BT** | ⚠️ Untested | Depends on module (likely AP6256) |
| **Controls** | ⚠️ Untested | GPIO buttons + ADC joysticks |
| **Battery** | ⚠️ Untested | CW2015 fuel gauge |
| **USB-C** | ⚠️ Untested | FUSB302 PD controller |
| **SD Card** | ✅ Should work | Standard SDHCI |
| **Serial** | ✅ Working | UART2 @ 1.5 Mbaud |

## Boot Process

```
1. Power On
   ↓
2. RK3399 ROM Code (in SoC)
   - Searches for bootloader at sector 64
   ↓
3. idbloader.img
   - Initializes DDR RAM
   - Loads miniloader
   ↓
4. U-Boot
   - Reads extlinux.conf from FAT32 partition
   - Loads kernel and device tree
   ↓
5. Linux Kernel
   - Uses rk3399-anbernic-rg552.dtb
   - Mounts root filesystem
   ↓
6. NixOS Init
```

## Troubleshooting

### Device won't boot

1. **Check bootloader placement**
   ```bash
   # Verify bootloader at sector 64
   sudo dd if=/dev/sdX bs=512 skip=64 count=1 | hexdump -C | head
   # Should show data, not all zeros
   ```

2. **Verify partition layout**
   ```bash
   sudo parted /dev/sdX print
   # Should show GPT with two partitions starting at 16MB
   ```

3. **Connect serial console**
   - UART2 on GPIO header
   - 1.5 Mbaud, 8N1
   - See boot messages for errors

### Serial Console Connection

```
RG552 GPIO Header:
Pin 6:  GND
Pin 8:  TXD (UART2_TX) - Connect to RX on USB-Serial adapter
Pin 10: RXD (UART2_RX) - Connect to TX on USB-Serial adapter

Screen command:
screen /dev/ttyUSB0 1500000
```

### Image build fails

- **Cross-compilation**: Building for aarch64 on x86_64 requires:
  ```nix
  # In configuration.nix
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  ```

- **Missing bootloader**: Make sure `u-boot-rockchip.bin` exists in `nixos/`

- **Device tree not compiled**: Run `dtc` to compile `.dts` to `.dtb`

## Technical Details

See [SD_CARD_LAYOUT.md](SD_CARD_LAYOUT.md) for:
- Complete boot sector layout
- Bootloader component details
- Partition table specifications
- extlinux.conf format

## Contributing

To improve hardware support:

1. **Test and report**: Boot NixOS and test each component
2. **Submit patches**: Device tree changes, kernel modules, etc.
3. **Add drivers**: Package RG552-specific drivers for NixOS

## Resources

- **ROCKNIX**: https://github.com/ROCKNIX/distribution
  - Source of device tree and bootloader
  - Reference for working configuration

- **Pine64 Wiki**: https://wiki.pine64.org/wiki/RK3399_boot_sequence
  - RK3399 boot process documentation

- **Rockchip Wiki**: http://opensource.rock-chips.com/
  - Official Rockchip open source documentation

- **NixOS Manual**: https://nixos.org/manual/nixos/stable/
  - NixOS configuration guide

## License

- Device tree (`rk3399-anbernic-rg552.dts`): GPL-2.0+ OR MIT (from ROCKNIX)
- Scripts and documentation: MIT
- NixOS modules: MIT

## Credits

- **ROCKNIX Team** - Device tree and bootloader work
- **Rockchip** - RK3399 reference code
- **Maya Matuszczyk** - Initial RG552 device tree work
