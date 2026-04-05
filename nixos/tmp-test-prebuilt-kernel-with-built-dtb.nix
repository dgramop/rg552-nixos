# TEMPORARY TEST: Hybrid configuration to debug display issue
# Uses prebuilt ROCKNIX kernel Image (known working) with our built DTB
# This isolates whether the problem is in the kernel Image or the device tree blob
{ config, lib, pkgs, ... }:

let
  # Prebuilt ROCKNIX kernel (for Image)
  rocknixKernel = pkgs.callPackage ./kernel-package.nix { };

  # Built kernel (for DTB)
  customKernel = pkgs.callPackage ./kernel-build-package.nix {
    inherit (pkgs.linuxKernel) buildLinux;
  };
in
{
  imports = [
    ./sd-image-rg552.nix
  ];

  # HYBRID: Use prebuilt Image but built DTB
  sdImage.populateFirmwareCommands = lib.mkForce ''
    # Copy ROCKNIX prebuilt kernel Image (known working)
    cp ${rocknixKernel}/Image firmware/Image

    # Copy NixOS initrd
    cp ${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile} firmware/initrd

    # Copy OUR BUILT device tree (testing if DTB is the problem)
    mkdir -p firmware/device_trees
    cp ${customKernel}/dtbs/rockchip/rk3399-anbernic-rg552.dtb firmware/device_trees/rk3399-anbernic-rg552.dtb

    # Create U-Boot boot script
    ${pkgs.gnused}/bin/sed \
      -e "s|@INIT@|init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}|g" \
      ${./boot.cmd} > firmware/boot.cmd.tmp

    ${pkgs.ubootTools}/bin/mkimage -C none -A arm64 -T script -d firmware/boot.cmd.tmp firmware/boot.scr
    rm firmware/boot.cmd.tmp
  '';

  boot.kernelParams = lib.mkForce [
    "console=ttyS2,1500000"
    "console=tty0"
    "loglevel=7"
  ];

  environment.systemPackages = with pkgs; [
    vim
    htop
    file
    usbutils
  ];

  networking.networkmanager.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  users.users.root.initialPassword = "nixos";

  networking = {
    hostName = "rg552-hybrid";
    useDHCP = false;
    wireless.enable = lib.mkDefault true;
  };

  system.stateVersion = "24.11";
}
