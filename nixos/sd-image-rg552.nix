# NixOS SD Image Builder for Anbernic RG552 (RK3399)
#
# This module creates bootable SD card images for the RG552.
# Based on nixpkgs' sd-image-aarch64.nix but adapted for RK3399 boot requirements.

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image.nix"
    ./kernel.nix
  ];

  # ARM64 platform
  nixpkgs.hostPlatform = "aarch64-linux";

  # Override sd-image settings for RG552 specific layout
  sdImage = {
    # Bootloader goes at sector 64 (32KB), so we need space before first partition
    # First partition starts at 16MB (sector 32768)
    firmwarePartitionOffset = 16;  # 16MB in MiB

    # System partition size (FAT32 boot partition)
    firmwareSize = 2048;  # 2GB in MiB

    # Don't compress by default (we can do it manually)
    compressImage = false;

    # Root filesystem population (handled by NixOS build system)
    populateRootCommands = "";

    # Populate firmware partition with boot files
    populateFirmwareCommands = ''
      # Copy kernel
      cp ${config.system.build.kernel}/${config.system.boot.loader.kernelFile} firmware/KERNEL

      # Copy initrd
      cp ${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile} firmware/initrd

      # Copy device tree
      mkdir -p firmware/device_trees
      cp ${../rk3399-anbernic-rg552.dtb} firmware/device_trees/rk3399-anbernic-rg552.dtb

      # Create extlinux boot configuration
      mkdir -p firmware/extlinux
      cat > firmware/extlinux/extlinux.conf <<EOF
LABEL NixOS
  LINUX /KERNEL
  INITRD /initrd
  FDT /device_trees/rk3399-anbernic-rg552.dtb
  APPEND init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}
EOF
    '';

    # Custom post-build command to install bootloader
    postBuildCommands = ''
      # Install bootloader at sector 64 (32KB offset)
      if [ -f "${./u-boot-rockchip.bin}" ]; then
        echo "Installing RK3399 bootloader at sector 64..."
        dd if=${./u-boot-rockchip.bin} of=$img bs=512 seek=64 conv=notrunc
      else
        echo "WARNING: u-boot-rockchip.bin not found!"
        echo "Run: ./get-bootloader.sh --download --output nixos/u-boot-rockchip.bin"
        exit 1
      fi

      # Fix boot flag on partition 1 (firmware), unset on partition 2 (root)
      # This improves U-Boot scan priority and reduces USB crash race condition
      echo "Fixing boot flags..."
      printf 'a\n1\na\n2\nw\n' | ${pkgs.util-linux}/bin/fdisk $img > /dev/null 2>&1
    '';
  };

  # Boot configuration
  boot = {
    # Kernel packages defined in kernel.nix (custom patched kernel)

    # Kernel parameters
    kernelParams = [
      "earlycon=uart8250,mmio32,0xff1a0000,115200n8"  # Early console at 115200 baud (ROCKNIX uses this)
      "console=tty1"
      "console=ttyS2,115200n8"  # Serial console at 115200 baud (matching ROCKNIX, not U-Boot's 1.5Mbaud)
      "rootwait"
      "loglevel=7"  # Verbose logging
    ];

    # Use extlinux boot (but we handle conf generation ourselves)
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = false;  # We generate extlinux.conf manually
    };

    # Explicitly set kernel and initrd filenames for our manual extlinux.conf
    loader.kernelFile = lib.mkDefault "Image";
    loader.initrdFile = lib.mkDefault "initrd";

    # Initial ramdisk
    initrd = {
      availableKernelModules = [
        # Storage
        "mmc_block"
        "sdhci_of_arasan"

        # Filesystem
        "ext4"
        "vfat"
      ];
    };
  };

  # Filesystems
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/NIXOS_SD";
      fsType = "ext4";
    };
  };

  # Basic system configuration
  networking.hostName = lib.mkDefault "rg552";

  # Enable serial console
  systemd.services."serial-getty@ttyS2" = {
    enable = true;
    wantedBy = [ "getty.target" ];
  };

  # Minimal system
  environment.systemPackages = with pkgs; [
    vim
    htop
  ];

  # This is required
  system.stateVersion = "24.11";
}
