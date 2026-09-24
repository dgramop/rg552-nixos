{ config, lib, pkgs, uboot, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/sd-card/sd-image.nix"
  ];

  sdImage = {
    firmwarePartitionOffset = 16;
    firmwareSize = 2048;
    compressImage = false;
    populateFirmwareCommands = "";
    populateRootCommands = lib.mkForce ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
    postBuildCommands = lib.mkForce ''
      dd if=${uboot}/u-boot-rockchip.bin of=$img bs=512 seek=64 conv=notrunc
    '';
  };
}
