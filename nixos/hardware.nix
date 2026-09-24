{ config, lib, pkgs, modulesPath, ... }:

let
  customKernel = pkgs.callPackage ./kernel.nix {
    inherit (pkgs.linuxKernel) buildLinux;
  };
  customKernelPackages = pkgs.linuxPackagesFor customKernel;
in
{
  nixpkgs.hostPlatform = "aarch64-linux";

  boot.kernelPackages = lib.mkForce customKernelPackages;
  boot.initrd.allowMissingModules = true;
  boot.kernelParams = lib.mkForce [
    "console=ttyS2,1500000"
    "console=tty0"
    "loglevel=7"
    "fbcon=rotate:3"
  ];

  hardware.deviceTree.name = "rockchip/rk3399-anbernic-rg552.dtb";

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  boot.initrd.systemd = {
    enable = true;
    emergencyAccess = true;
  };
  boot.initrd.availableKernelModules = [
    "mmc_block"
    "sdhci_of_arasan"
    "ext4"
    "vfat"
  ];

  hardware.firmware = [ pkgs.linux-firmware ];
  boot.kernelModules = [ "rtl8xxxu" ];
  systemd.services.wifi-power = {
    description = "WiFi power (GPIO3_C1)";
    wantedBy = [ "multi-user.target" ];
    before = [ "NetworkManager.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.libgpiod}/bin/gpioset -c 3 17=1";
      Restart = "on-failure";
    };
  };

  services.xserver.videoDrivers = [ "modesetting" ];
  services.xserver.xrandrHeads = [{
    output = "DSI-1";
    monitorConfig = ''
      Option "Rotate" "left"
    '';
  }];
  services.xserver.inputClassSections = [''
    Identifier "Goodix Touchscreen"
    MatchProduct "Goodix"
    Option "TransformationMatrix" "0 -1 1 1 0 0 0 0 1"
  ''];
}
