# Build U-Boot for RK3399 (aarch64-linux).
# Produces u-boot-dtb.bin which gets packed by uboot-rockchip.nix on x86_64.
{ buildUBoot, armTrustedFirmwareRK3399 }:

let
  atf = armTrustedFirmwareRK3399.override { platformCanUseHDCPBlob = false; };
in
buildUBoot {
  defconfig = "evb-rk3399_defconfig";
  extraMeta.platforms = [ "aarch64-linux" ];
  env.BL31 = "${atf}/bl31.elf";
  extraConfig = "CONFIG_EFI_LOADER=n";
  filesToInstall = [ "u-boot-dtb.bin" ];
}
