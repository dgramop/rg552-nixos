# NixOS configuration for Anbernic RG552
# Uses buildLinux to compile Linux 6.18.20 with ROCKNIX patches
{ config, lib, pkgs, glibc-x86, ... }:

let
  # Build custom kernel using buildLinux
  customKernel = pkgs.callPackage ./kernel-build-package.nix {
    inherit (pkgs.linuxKernel) buildLinux;
  };

  # Create custom kernel packages set
  customKernelPackages = pkgs.linuxPackagesFor customKernel;

  # Build U-Boot bootloader for RK3399
  # Uses qemu to run x86_64 rkbin tools on aarch64 (same as nixpkgs rkboot)
  uboot = pkgs.callPackage ./uboot-package.nix {
    inherit (pkgs) buildUBoot armTrustedFirmwareRK3399 rkbin qemu;
    inherit glibc-x86;
  };

  # Build rocknix-joypad driver for RG552 controls
  rocknixJoypad = customKernelPackages.callPackage ./rocknix-joypad-driver.nix {};

in
{
  imports = [
    ./sd-image-rg552.nix
  ];

  # Allow unfree for Rockchip bootloader tools (rkbin)
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [ "u-boot-rg552" "rkbin" ];

  # Use our custom-built kernel
  boot.kernelPackages = lib.mkForce customKernelPackages;

  # TODO: Add ROCKNIX joypad driver for RG552 controls
  # The joypad driver needs to be built in-tree with the kernel, not as an external module
  # For now, building without it to get a working base system
  # boot.extraModulePackages = [ rocknixJoypad ];
  # boot.kernelModules = [ "rocknix-singleadc-joypad" ];

  # Populate firmware partition with kernel, initrd, device tree, and boot script
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

  # Install U-Boot bootloader into raw image sectors
  sdImage.postBuildCommands = lib.mkForce ''
    # Combined bootloader (DDR init + SPL + U-Boot + ATF) at sector 64
    dd if=${uboot}/u-boot-rockchip.bin of=$img bs=512 seek=64 conv=notrunc

    # Fix boot flags: enable on partition 1 (firmware), disable on partition 2 (root)
    # Improves U-Boot scan priority and avoids USB crash race condition
    printf 'a\n1\na\n2\nw\n' | ${pkgs.util-linux}/bin/fdisk $img 2>&1 || true
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
    hostName = "rg552";
    useDHCP = false;
    wireless.enable = lib.mkDefault true;
  };

  system.stateVersion = "24.11";
}
