# RG552 NixOS

NixOS on the Anbernic RG552 (RK3399). Builds U-Boot, ARM Trusted Firmware, and a custom Linux 6.18.20 kernel with ROCKNIX hardware patches — all from source in Nix — and produces a flashable SD card image.

Heavily leaned on the ROCKNIX project for devicetrees, patches, and kernel drivers + pine project for docs

## Build & Flash

- **Build the SD image**: `nix build` (first build compiles kernel + U-Boot, ~3-4 hours; cached after that)
- **Build just the kernel**: `nix build '.#kernel'`
- **Build just U-Boot**: `nix build '.#uboot'`
- **Flash**: `sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress conv=fsync`
- **Serial console** (for debugging): UART2 on GPIO pins 6 (GND), 8 (TX), 10 (RX) — `screen /dev/ttyUSB0 1500000`

## SD Card Layout

The RK3399 ROM loads a bootloader from a fixed offset, then U-Boot reads the firmware partition to boot Linux.

| Region | Sector | Offset | Contents |
|--------|--------|--------|----------|
| MBR/GPT | 0–63 | 0x0 | Partition table |
| idbloader (TPL+SPL) | 64+ | 32 KB | DRAM init + Secondary Program Loader |
| u-boot.itb | 16384+ | 8 MB | U-Boot + ATF BL31 (FIT image) |
| Firmware (FAT32) | 32768+ | 16 MB | Kernel `Image`, `initrd`, device tree, `boot.scr` |
| Root (ext4) | after firmware | — | NixOS root filesystem |
