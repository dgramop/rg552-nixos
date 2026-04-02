# NixOS configuration for Anbernic RG552
# Uses ROCKNIX's proven kernel with NixOS userspace
{ config, lib, pkgs, ... }:

let
  rocknixKernel = pkgs.callPackage ./kernel-package.nix { };
in
{
  imports = [
    ./sd-image-rg552.nix
  ];

  # Override firmware population to use ROCKNIX kernel
  # Everything else (U-Boot, partition layout, etc.) stays the same
  sdImage.populateFirmwareCommands = lib.mkForce ''
    # Copy ROCKNIX kernel as "Image"
    cp ${rocknixKernel}/Image firmware/Image

    # Copy NixOS initrd (still needed for NixOS boot)
    cp ${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile} firmware/initrd

    # Copy ROCKNIX device tree (they might have different settings)
    mkdir -p firmware/device_trees
    cp ${rocknixKernel}/dtbs/rk3399-anbernic-rg552.dtb firmware/device_trees/rk3399-anbernic-rg552.dtb

    # Create U-Boot boot script with proper init path
    ${pkgs.gnused}/bin/sed \
      -e "s|@INIT@|init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}|g" \
      ${./boot.cmd} > firmware/boot.cmd.tmp

    # Compile boot script
    ${pkgs.ubootTools}/bin/mkimage -C none -A arm64 -T script -d firmware/boot.cmd.tmp firmware/boot.scr
    rm firmware/boot.cmd.tmp
  '';

  # Boot parameters (use console=ttyS2 like ROCKNIX does)
  boot.kernelParams = lib.mkForce [
    "console=ttyS2,1500000"
    "console=tty0"
    "loglevel=7"
  ];

  # Minimal packages
  environment.systemPackages = with pkgs; [
    vim
    htop
    file
  ];

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  # Set root password (change this!)
  users.users.root.initialPassword = "nixos";

  # Networking
  networking = {
    hostName = "rg552";
    useDHCP = false;
    interfaces.eth0.useDHCP = lib.mkDefault true;
    wireless.enable = lib.mkDefault false;  # Enable if you have WiFi working
  };

  system.stateVersion = "24.11";
}
