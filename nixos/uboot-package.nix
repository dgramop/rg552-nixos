{ stdenv, lib, buildUBoot, armTrustedFirmwareRK3399, rkbin, qemu, glibc-x86 }:

let
  # Build ATF without the unfree HDCP blob (not needed for RG552)
  atf = armTrustedFirmwareRK3399.override { platformCanUseHDCPBlob = false; };

  # Build U-Boot to get u-boot-dtb.bin
  ubootDrv = buildUBoot {
    defconfig = "evb-rk3399_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    env.BL31 = "${atf}/bl31.elf";
    extraConfig = "CONFIG_EFI_LOADER=n";
    filesToInstall = [ "u-boot-dtb.bin" ];
  };

  # Run x86_64 rkbin tools via qemu on aarch64 (same pattern as nixpkgs rkboot)
  # -L sets the sysroot so qemu can find the x86_64 dynamic linker
  run = lib.optionalString stdenv.hostPlatform.isAarch64
    "${qemu}/bin/qemu-x86_64 -L ${glibc-x86}";
in
stdenv.mkDerivation {
  pname = "u-boot-rg552";
  version = "2025.10";

  dontUnpack = true;

  buildPhase = ''
    cp ${rkbin}/bin/rk33/rk3399_ddr_933MHz_v1.30.bin ddr.bin
    cp ${rkbin}/bin/rk33/rk3399_miniloader_v1.30.bin miniloader.bin

    # 1. idbloader.img (DDR init + miniloader)
    ${run} ${rkbin.src}/tools/mkimage -n rk3399 -T rksd -d ddr.bin idbloader.img
    cat miniloader.bin >> idbloader.img

    # 2. uboot.img (U-Boot packed in Rockchip format)
    ${run} ${rkbin.src}/tools/loaderimage --pack --uboot ${ubootDrv}/u-boot-dtb.bin uboot.img 0x00200000

    # 3. trust.img (ATF BL31 in Rockchip format)
    #    Replicate rkbin directory layout so trust_merger finds files on both passes
    mkdir -p bin/rk33
    cp ${rkbin.src}/bin/rk33/rk3399_bl31_v1.36.elf bin/rk33/
    cp ${rkbin.src}/bin/rk33/rk3399_bl32_v2.12.bin bin/rk33/
    cp ${rkbin.src}/RKTRUST/RK3399TRUST.ini .
    ${run} ${rkbin.src}/tools/trust_merger --ignore-bl32 RK3399TRUST.ini
    ${run} ${rkbin.src}/tools/trust_merger --ignore-bl32 RK3399TRUST.ini

    # 4. Combine at ROCKNIX sector offsets
    dd if=idbloader.img of=u-boot-rockchip.bin bs=512 seek=0 conv=fsync,notrunc
    dd if=uboot.img of=u-boot-rockchip.bin bs=512 seek=16320 conv=fsync,notrunc
    dd if=trust.img of=u-boot-rockchip.bin bs=512 seek=24512 conv=fsync,notrunc
  '';

  installPhase = ''
    mkdir -p $out
    cp u-boot-rockchip.bin $out/
  '';

  meta = {
    description = "U-Boot bootloader for Anbernic RG552 (RK3399) using Rockchip miniloader";
    platforms = [ "aarch64-linux" "x86_64-linux" ];
    license = lib.licenses.unfreeRedistributable;
  };
}
