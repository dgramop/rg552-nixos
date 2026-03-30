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
      # Copy uncompressed kernel
      # Note: Compression doesn't help with memory overlap since U-Boot decompresses before booting
      cp ${config.system.build.kernel}/Image firmware/Image

      # Copy initrd
      cp ${config.system.build.initialRamdisk}/initrd firmware/initrd

      # Copy device tree
      mkdir -p firmware/device_trees
      cp ${../rk3399-anbernic-rg552.dtb} firmware/device_trees/rk3399-anbernic-rg552.dtb

      # Create U-Boot boot script with proper init path and kernel params
      # Substitute @INIT@ placeholder with actual init path
      ${pkgs.gnused}/bin/sed \
        -e "s|@INIT@|init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}|g" \
        ${./boot.cmd} > firmware/boot.cmd.tmp

      # Compile boot script
      ${pkgs.ubootTools}/bin/mkimage -C none -A arm64 -T script -d firmware/boot.cmd.tmp firmware/boot.scr
      rm firmware/boot.cmd.tmp
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
      echo "Before fdisk:"
      ${pkgs.util-linux}/bin/fdisk -l $img | grep "^$img"

      # Toggle boot flags: enable on partition 1, disable on partition 2
      printf 'a\n1\na\n2\nw\n' | ${pkgs.util-linux}/bin/fdisk $img 2>&1 | grep -E "(bootable|partition table|Writing)" || true

      echo "After fdisk:"
      ${pkgs.util-linux}/bin/fdisk -l $img | grep "^$img"

      # Verify that partition 1 has boot flag and partition 2 doesn't
      if ${pkgs.util-linux}/bin/fdisk -l $img | grep "^''${img}1" | grep -q '\*'; then
        echo "✓ Boot flag correctly set on partition 1 (firmware)"
      else
        echo "✗ ERROR: Boot flag NOT set on partition 1 (firmware)"
        exit 1
      fi

      if ! ${pkgs.util-linux}/bin/fdisk -l $img | grep "^''${img}2" | grep -q '\*'; then
        echo "✓ Boot flag correctly unset on partition 2 (root)"
      else
        echo "✗ ERROR: Boot flag incorrectly set on partition 2 (root)"
        exit 1
      fi
    '';
  };

  # Boot configuration
  boot = {
    # Kernel packages defined in kernel.nix (custom patched kernel)

    # Kernel parameters
    # Using Android's earlycon syntax: NO baud rate specified!
    # The UART is already configured to 1500000 by U-Boot, kernel inherits it
    kernelParams = [
      "earlycon=uart8250,mmio32,0xff1a0000"  # Early console (no baud rate - inherit from U-Boot)
      "console=tty1"
      "console=ttyS2,1500000n8"  # Serial console at 1.5Mbaud
      "rootwait"
      "loglevel=7"  # Verbose logging
      "systemd.log_level=debug"  # Debug logging for systemd in initrd
      "systemd.log_target=console"  # Send systemd logs to console
      "rd.debug"  # Enable initramfs debugging
    ];

    # Enable systemd in initrd with debug shell
    initrd.systemd = {
      enable = true;
      emergencyAccess = true;  # Allow emergency shell access
    };

    # Use extlinux boot (but we handle conf generation ourselves)
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = false;  # We generate extlinux.conf manually
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
