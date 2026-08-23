# NixOS SD Image Builder for Anbernic RG552 (RK3399)
#
# This module creates bootable SD card images for the RG552.
# Based on nixpkgs' sd-image-aarch64.nix but adapted for RK3399 boot requirements.

{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image.nix"
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

    # Firmware partition unused — U-Boot lives at raw sectors (see base.nix
    # postBuildCommands), and kernel/initrd/dtb are loaded from the ext4 root
    # via extlinux (see populateRootCommands in base.nix).
    populateFirmwareCommands = "";

    # Bootloader installation is handled by configuration.nix
    # via sdImage.postBuildCommands override
  };

  # Boot configuration
  boot = {
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

    # Use extlinux (distro boot): U-Boot's stock env scans for
    # /boot/extlinux/extlinux.conf on ext4 and sysboot's it.
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
