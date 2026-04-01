# Test configuration that uses EXACT same U-Boot layout as production
# but replaces the kernel with bare-metal test kernel
{ config, lib, pkgs, ... }:

let
  testKernel = pkgs.callPackage ./test-kernel-package.nix { };
in
{
  imports = [
    ./sd-image-rg552.nix
  ];

  # Override ONLY the firmware population to use test kernel
  # Everything else (U-Boot at sector 64, partition layout, etc) stays the same
  sdImage.populateFirmwareCommands = lib.mkForce ''
    # Copy test kernel as "test-kernel" (for manual testing)
    cp ${testKernel}/Image firmware/test-kernel

    # Copy device tree (still needed for booti command)
    mkdir -p firmware/device_trees
    cp ${../rk3399-anbernic-rg552.dtb} firmware/device_trees/rk3399-anbernic-rg552.dtb

    # Copy test boot script as boot.scr (auto-loads test-kernel)
    cp ${testKernel}/boot.scr firmware/boot.scr
  '';

  # Disable kernel build since we're not using it
  # This speeds up the build significantly
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages_latest;  # Dummy, won't be used

  # Minimal config - test kernel won't actually boot to NixOS
  services.openssh.enable = lib.mkForce false;
  environment.systemPackages = lib.mkForce [];
}
