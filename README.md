# RG552 NixOS

NixOS on the Anbernic RG552 (RK3399). Builds a custom Linux 6.18.20 kernel with ROCKNIX hardware patches and produces a flashable SD card image.

## Build & Flash

- **Get the bootloader** (one-time): `./get-bootloader.sh --download --output nixos/u-boot-rockchip.bin`
- **Build the SD image**: `nix build` (first build compiles the kernel, ~3-4 hours; cached after that)
- **Build just the kernel**: `nix build '.#kernel'`
- **Flash**: `sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync`
- **Serial console** (for debugging): UART2 on GPIO pins 6 (GND), 8 (TX), 10 (RX) — `screen /dev/ttyUSB0 1500000`

## SD Card Layout

The RK3399 ROM loads a bootloader from a fixed offset, then U-Boot reads the firmware partition to boot Linux.

| Region | Sector | Offset | Contents |
|--------|--------|--------|----------|
| MBR/GPT | 0–63 | 0x0 | Partition table |
| Bootloader | 64+ | 32 KB | `u-boot-rockchip.bin` (idbloader + U-Boot + ATF) |
| Firmware (FAT32) | 32768+ | 16 MB | Kernel `Image`, `initrd`, device tree, `boot.scr` |
| Root (ext4) | after firmware | — | NixOS root filesystem |
