# RG552 hardware base configuration
# Hardware-specific config that any RG552 NixOS system needs.
# Import this from your configuration.nix.
{ config, lib, pkgs, uboot, ... }:

let
  customKernel = pkgs.callPackage ./kernel.nix {
    inherit (pkgs.linuxKernel) buildLinux;
  };
  customKernelPackages = pkgs.linuxPackagesFor customKernel;
  rocknixJoypad = customKernelPackages.callPackage ./rocknix-joypad-driver.nix {};
in
{
  imports = [
    ./sd-image-rg552.nix
  ];

  # Kernel
  boot.kernelPackages = lib.mkForce customKernelPackages;
  boot.initrd.allowMissingModules = true;

  # boot.extraModulePackages = [ rocknixJoypad ];  # Can't build out-of-tree (needs INPUT_POLLDEV symbols)

  # Boot parameters
  boot.kernelParams = lib.mkForce [
    "console=ttyS2,1500000"
    "console=tty0"
    "loglevel=7"
    "fbcon=rotate:3"
  ];

  # DTB for this board — extlinux uses this to emit the FDT line.
  hardware.deviceTree.name = "rockchip/rk3399-anbernic-rg552.dtb";

  # Seed /boot/extlinux/extlinux.conf on the ext4 root at image-build time.
  # At runtime, generic-extlinux-compatible keeps this in sync per generation.
  sdImage.populateRootCommands = lib.mkForce ''
    mkdir -p ./files/boot
    ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
  '';

  # Bootloader (U-Boot at sector 64). sd-image already marks p2 (ext4 root)
  # bootable, which is what distro-boot needs to find /boot/extlinux/extlinux.conf.
  # (Previously we toggled bootable to p1 for the boot.scr-on-FAT flow — no
  # longer needed and actively harmful for extlinux.)
  sdImage.postBuildCommands = lib.mkForce ''
    dd if=${uboot}/u-boot-rockchip.bin of=$img bs=512 seek=64 conv=notrunc
  '';

  # WiFi (RTL8188FTV USB)
  hardware.firmware = [ pkgs.linux-firmware ];
  boot.kernelModules = [ "rtl8xxxu" ];

  # WiFi chip power — GPIO3_C1 enables the USB WiFi adapter
  systemd.services.wifi-power = {
    description = "WiFi power (GPIO3_C1)";
    wantedBy = [ "multi-user.target" ];
    before = [ "NetworkManager.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.libgpiod}/bin/gpioset -c 3 17=1";
      Restart = "on-failure";
    };
  };

  # Networking
  networking.networkmanager.enable = true;
  networking.hostName = lib.mkDefault "rg552";
  networking.useDHCP = false;

  # Use modesetting driver (fbdev has broken ABI on this nixpkgs)
  services.xserver.videoDrivers = [ "modesetting" ];

  # Display rotation (Sharp panel is natively portrait 1152x1920)
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

  # Serial console
  systemd.services."serial-getty@ttyS2" = {
    enable = true;
    wantedBy = [ "getty.target" ];
  };

  # Flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "24.11";
}
