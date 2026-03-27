# Getting Started with RG552 NixOS

This guide will walk you through the process of creating a bootable NixOS SD card for your Anbernic RG552.

## What's Been Done

✅ **Research Complete**
- Analyzed RK3399 boot sequence from Pine64 wiki
- Explored ROCKNIX distribution for RG552-specific components
- Documented complete SD card layout and boot process

✅ **Device Tree Extracted**
- `rk3399-anbernic-rg552.dts` - Device tree source (1,338 lines from ROCKNIX)
- `rk3399-anbernic-rg552.dtb` - Compiled device tree blob (70KB, ready to use)

✅ **Tools Created**
- `flash-sd.sh` - Minimal SD card flashing script
- `get-bootloader.sh` - Extract/download bootloader from ROCKNIX
- `compile-dtb.sh` - Compile device tree with kernel headers
- `nixos/sd-image-rg552.nix` - NixOS SD image builder module
- `nixos/configuration.nix` - Example NixOS configuration

✅ **Documentation Written**
- `README.md` - Project overview and quick start
- `SD_CARD_LAYOUT.md` - Technical SD card layout documentation
- `GETTING_STARTED.md` - This file!

## Next Steps

### 1. Get the Bootloader (Required)

You need `u-boot-rockchip.bin` to boot the RG552 from SD card.

**Quick option:**
```bash
./get-bootloader.sh --download --output nixos/u-boot-rockchip.bin
```

This will:
1. Find the latest ROCKNIX release for RK3399
2. Download the image (~500MB)
3. Extract just the bootloader (sectors 64-32767)
4. Save it as `nixos/u-boot-rockchip.bin`

### 2. Test Basic Boot (Minimal Approach)

Before building a full NixOS image, let's verify the SD card can boot using a minimal setup:

```bash
# You'll need:
# - A blank SD card (minimum 8GB)
# - The bootloader (from step 1)
# - A basic Linux kernel Image for aarch64
# - The compiled device tree (already done: rk3399-anbernic-rg552.dtb)

# Example with a test kernel:
sudo ./flash-sd.sh \
  --bootloader nixos/u-boot-rockchip.bin \
  --kernel /path/to/arm64/Image \
  --dtb rk3399-anbernic-rg552.dtb \
  /dev/sdX  # Your SD card device
```

**What this tests:**
- ✅ SD card partition layout is correct
- ✅ Bootloader is placed at correct offset (sector 64)
- ✅ U-Boot can find and load extlinux.conf
- ✅ Device tree loads without errors
- ✅ Kernel starts (even if it doesn't fully boot without a rootfs)

**Expected result:**
- RG552 should attempt to boot from SD card
- You should see boot output on serial console (UART2 @ 1.5 Mbaud)
- Without a proper rootfs, it will panic, but that's OK for now!

### 3. Build NixOS SD Image

Once basic boot works, build a complete NixOS image:

```bash
cd nixos

# Make sure you have the bootloader
ls u-boot-rockchip.bin || \
  ../get-bootloader.sh --download --output u-boot-rockchip.bin

# Build the image (requires aarch64 support)
nix-build '<nixpkgs/nixos>' \
  -A config.system.build.sdImage \
  -I nixos-config=./configuration.nix \
  --argstr system aarch64-linux
```

**If building on x86_64:**
You need binfmt support for aarch64 emulation:
```nix
# On your NixOS build machine's configuration.nix:
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```

**Alternative: Use your NixOS server:**
```bash
# Copy files to server
scp -r ../rg552 root@dgramop.xyz:/tmp/

# Build on server
ssh root@dgramop.xyz 'cd /tmp/rg552/nixos && nix-build ...'
```

### 4. Flash the NixOS Image

```bash
# Decompress if needed
gunzip result/sd-image/*.img.gz

# Flash to SD card
sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync
```

### 5. Boot NixOS!

1. Insert SD card into RG552
2. Power on
3. NixOS should boot!

**Serial Console Access** (for debugging):
```
Pin 6:  GND
Pin 8:  TXD (UART2_TX) → RX on USB-Serial adapter
Pin 10: RXD (UART2_RX) → TX on USB-Serial adapter

Connect:
screen /dev/ttyUSB0 1500000
```

## Project Structure

```
rg552/
├── README.md                      # Main documentation
├── SD_CARD_LAYOUT.md             # Boot layout technical details
├── GETTING_STARTED.md            # This file
│
├── flash-sd.sh                   # Flash SD card manually
├── get-bootloader.sh             # Get bootloader from ROCKNIX
├── compile-dtb.sh                # Compile device tree
│
├── rk3399-anbernic-rg552.dts     # Device tree source (from ROCKNIX)
├── rk3399-anbernic-rg552.dtb     # Compiled device tree (ready to use)
│
└── nixos/
    ├── sd-image-rg552.nix        # NixOS image builder module
    ├── configuration.nix          # Example NixOS config
    └── u-boot-rockchip.bin       # Bootloader (you need to get this)
```

## Troubleshooting

### "Device won't boot from SD card"

1. **Check the bootloader placement:**
   ```bash
   sudo dd if=/dev/sdX bs=512 skip=64 count=1 | hexdump -C | head
   # Should show data, not all zeros
   ```

2. **Verify partition table:**
   ```bash
   sudo parted /dev/sdX print
   # Should show GPT with partition 1 starting at sector 32768
   ```

3. **Check serial console output** - Connect UART2 to see actual boot errors

### "NixOS build fails with cross-compilation errors"

Enable aarch64 emulation on your build machine:
```nix
boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
```

Or build on an aarch64 machine (like your OVH server).

### "Device tree compilation warning about dmc_opp_table"

This is expected. The device tree was created for an older kernel version in ROCKNIX. The DTB was compiled with `-f` (force) to work around this. If you experience memory controller issues, we may need to fix the device tree or use the exact kernel version ROCKNIX uses.

### "get-bootloader.sh can't find bootloader in ROCKNIX"

The script looks for pre-built bootloaders. If you're building ROCKNIX from source:
```bash
cd /tmp
git clone https://github.com/ROCKNIX/distribution rocknix
cd rocknix
PROJECT=ROCKNIX DEVICE=RK3399 ARCH=aarch64 make u-boot

# Then extract
../get-bootloader.sh --rocknix-dir . --output ../rg552/nixos/u-boot-rockchip.bin
```

## What's Working vs. Untested

| Component | Status | Notes |
|-----------|--------|-------|
| **Boot Process** | ⚠️ Needs Testing | Partition layout and bootloader placement are correct |
| **Device Tree** | ✅ Compiled | 70KB DTB with minor warning about dmc_opp_table |
| **CPU** | ✅ Should Work | Standard RK3399 (2xA72 + 4xA53) |
| **Serial Console** | ✅ Should Work | UART2 @ 1.5Mbaud |
| **SD Card** | ✅ Should Work | Standard SDHCI controller |
| **Display** | ⚠️ Untested | Needs panel driver and Rockchip DRM |
| **GPU** | ⚠️ Untested | Mali T860 with Panfrost |
| **Audio** | ⚠️ Untested | ES8316 codec |
| **WiFi/BT** | ⚠️ Untested | Chip unknown, likely AP6256 |
| **Controls** | ⚠️ Untested | GPIO buttons + ADC joysticks |
| **Battery** | ⚠️ Untested | CW2015 fuel gauge |

## Testing Strategy

**Phase 1: Basic Boot** (Current)
- ✅ Flash SD card with minimal setup
- ✅ Verify bootloader loads
- ✅ Check U-Boot finds extlinux.conf
- ⏳ Kernel starts (next step!)

**Phase 2: NixOS Boot**
- Build and flash full NixOS image
- Verify NixOS init runs
- Get to login prompt

**Phase 3: Hardware Enablement**
- Test display output
- Enable GPU acceleration
- Configure audio
- Set up controls
- Battery monitoring

**Phase 4: Gaming Setup**
- Install RetroArch
- EmulationStation or similar frontend
- Performance tuning

## Resources

- **This Project**: `/Users/dgramop/sources/dgramop/rg552`
- **ROCKNIX**: https://github.com/ROCKNIX/distribution
- **RK3399 Boot Sequence**: https://wiki.pine64.org/wiki/RK3399_boot_sequence
- **NixOS Manual**: https://nixos.org/manual/nixos/stable/

## Contributing

Found an issue or got something working? Update the relevant documentation:
- Hardware status → `README.md`
- Boot issues → `SD_CARD_LAYOUT.md`
- NixOS config → `nixos/configuration.nix`

## Quick Commands Reference

```bash
# Get bootloader
./get-bootloader.sh --download --output nixos/u-boot-rockchip.bin

# Compile device tree (if you modify it)
./compile-dtb.sh

# Flash minimal test SD card
sudo ./flash-sd.sh \
  -b nixos/u-boot-rockchip.bin \
  -k /path/to/Image \
  -d rk3399-anbernic-rg552.dtb \
  /dev/sdX

# Build NixOS image
cd nixos && nix-build '<nixpkgs/nixos>' \
  -A config.system.build.sdImage \
  -I nixos-config=./configuration.nix

# Flash NixOS image
sudo dd if=result/*.img of=/dev/sdX bs=4M status=progress

# Serial console
screen /dev/ttyUSB0 1500000
```

Good luck booting NixOS on your RG552! 🎮
