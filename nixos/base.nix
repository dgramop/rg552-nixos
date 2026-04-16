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

  # TODO: Add ROCKNIX joypad driver for RG552 controls
  # The joypad driver needs to be built in-tree with the kernel, not as an external module
  # boot.extraModulePackages = [ rocknixJoypad ];
  # boot.kernelModules = [ "rocknix-singleadc-joypad" ];

  # Boot parameters
  boot.kernelParams = lib.mkForce [
    "console=ttyS2,1500000"
    "console=tty0"
    "loglevel=7"
    "fbcon=rotate:3"
  ];

  # Firmware partition (kernel, initrd, device tree, boot script)
  sdImage.populateFirmwareCommands = lib.mkForce ''
    cp ${customKernel}/Image firmware/Image
    cp ${config.system.build.initialRamdisk}/${config.system.boot.loader.initrdFile} firmware/initrd
    mkdir -p firmware/device_trees
    cp ${customKernel}/dtbs/rockchip/rk3399-anbernic-rg552.dtb firmware/device_trees/rk3399-anbernic-rg552.dtb
    ${pkgs.gnused}/bin/sed \
      -e "s|@INIT@|init=${config.system.build.toplevel}/init ${toString config.boot.kernelParams}|g" \
      ${./boot.cmd} > firmware/boot.cmd.tmp
    ${pkgs.ubootTools}/bin/mkimage -C none -A arm64 -T script -d firmware/boot.cmd.tmp firmware/boot.scr
    rm firmware/boot.cmd.tmp
  '';

  # Bootloader (U-Boot at sector 64)
  sdImage.postBuildCommands = lib.mkForce ''
    dd if=${uboot}/u-boot-rockchip.bin of=$img bs=512 seek=64 conv=notrunc
    printf 'a\n1\na\n2\nw\n' | ${pkgs.util-linux}/bin/fdisk $img 2>&1 || true
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
