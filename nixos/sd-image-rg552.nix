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

      # Copy device tree
      mkdir -p firmware/device_trees
      cp ${../rk3399-anbernic-rg552.dtb} firmware/device_trees/rk3399-anbernic-rg552.dtb

      # Create extlinux boot configuration
      mkdir -p firmware/extlinux
      cat > firmware/extlinux/extlinux.conf <<EOF
LABEL NixOS
  LINUX /KERNEL
  FDT /device_trees/rk3399-anbernic-rg552.dtb
  APPEND ${toString config.boot.kernelParams}
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

      # TODO: Fix boot flag on partition 1 (firmware) instead of partition 2 (root)
      # This improves U-Boot scan priority and reduces USB crash race condition.
      # Currently requires manual fix: echo -e 'a\n1\na\n2\nw' | fdisk $img
      # Should integrate into build process using sfdisk or parted for automation.
    '';
  };

  # Boot configuration
  boot = {
    # Kernel packages defined in kernel.nix (custom patched kernel)

    # Kernel parameters
    kernelParams = [
      "earlycon"  # Early console (auto-detects from DT stdout-path = serial2:1500000n8)
      "console=tty1"
      "console=ttyS2,1500000n8"  # Serial console (UART2 at 0xff1a0000)
      "rootwait"
      "loglevel=7"  # Verbose kernel messages for debugging (overridden by loglevel=4 from NixOS defaults)
    ];

    # Use extlinux boot
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };

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
