# NixOS configuration for Anbernic RG552 with BUILT kernel
# Uses buildLinux to compile Linux 6.18.20 with ROCKNIX patches
# For faster builds, use configuration.nix which uses prebuilt kernel
{ config, lib, pkgs, ... }:

let
  # Build custom kernel using buildLinux
  customKernel = pkgs.callPackage ./kernel-build-package.nix {
    inherit (pkgs.linuxKernel) buildLinux;
  };

  # Create custom kernel packages set
  customKernelPackages = pkgs.linuxPackagesFor customKernel;

  # Build rocknix-joypad driver for RG552 controls
  rocknixJoypad = customKernelPackages.callPackage ./rocknix-joypad-driver.nix {};

in
{
  imports = [
    ./sd-image-rg552.nix
  ];

  # Use our custom-built kernel
  boot.kernelPackages = lib.mkForce customKernelPackages;

  # TODO: Add ROCKNIX joypad driver for RG552 controls
  # The joypad driver needs to be built in-tree with the kernel, not as an external module
  # For now, building without it to get a working base system
  # boot.extraModulePackages = [ rocknixJoypad ];
  # boot.kernelModules = [ "rocknix-singleadc-joypad" ];

  # Override firmware population to use built kernel outputs
  # CRITICAL: buildLinux outputs DTB to dtbs/rockchip/ (note subdirectory)
  # This is different from prebuilt kernel which has flat dtbs/ structure
  sdImage.populateFirmwareCommands = lib.mkForce ''
    # Copy custom-built kernel Image
    cp ${customKernel}/Image firmware/Image

    # Copy NixOS initrd (still needed for NixOS boot)
    cp ${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile} firmware/initrd

    # Copy device tree from buildLinux output
    # NOTE: buildLinux creates dtbs/rockchip/ subdirectory structure
    mkdir -p firmware/device_trees
    cp ${customKernel}/dtbs/rockchip/rk3399-anbernic-rg552.dtb firmware/device_trees/rk3399-anbernic-rg552.dtb

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

  # ROCKNIX kernel doesn't have all NixOS default modules (like RAID controllers)
  # Allow missing modules instead of failing the build
  boot.initrd.allowMissingModules = true;

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    htop
    file
    usbutils
  ];

  # Plymouth boot splash
  services.plymouth-lite = {
    enable = true;
    splashImage = ./rg552.png;
  };

  # Networking
  networking.networkmanager.enable = true;

  # Desktop environment
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  # Set root password (change this!)
  users.users.root.initialPassword = "nixos";

  # Networking configuration
  networking = {
    hostName = "rg552-built";
    useDHCP = false;
    wireless.enable = lib.mkDefault true;
  };

  system.stateVersion = "24.11";
}
