# Assemble U-Boot bootloader for RG552 using Rockchip miniloader approach.
# Produces a combined u-boot-rockchip.bin matching the ROCKNIX layout.
#
# The rkbin tools (loaderimage, trust_merger) are x86_64 Linux binaries,
# so this derivation must be built on x86_64-linux. The U-Boot binary
# (ubootDrv) is built on aarch64-linux and pulled in as a dependency.
{ stdenv, lib, rkbin, ubootDrv }:

let
  # Invoke the dynamic linker directly to run unpatched x86_64 rkbin tools
  ld = "${stdenv.cc.libc}/lib/ld-linux-x86-64.so.2";
  run = "${ld} --library-path ${stdenv.cc.libc}/lib ${rkbin.src}/tools";
in
stdenv.mkDerivation {
  pname = "u-boot-rg552";
  version = "2025.10";

  dontUnpack = true;

  buildPhase = ''

    cp ${rkbin}/bin/rk33/rk3399_ddr_933MHz_v1.30.bin ddr.bin
    cp ${rkbin}/bin/rk33/rk3399_miniloader_v1.30.bin miniloader.bin

    # 1. idbloader.img (DDR init + miniloader)
    ${run}/mkimage -n rk3399 -T rksd -d ddr.bin idbloader.img
    cat miniloader.bin >> idbloader.img

    # 2. uboot.img (U-Boot packed in Rockchip format)
    ${run}/loaderimage --pack --uboot ${ubootDrv}/u-boot-dtb.bin uboot.img 0x00200000

    # 3. trust.img (ATF BL31 in Rockchip format)
    mkdir -p bin/rk33
    cp ${rkbin.src}/bin/rk33/rk3399_bl31_v1.36.elf bin/rk33/
    cp ${rkbin.src}/bin/rk33/rk3399_bl32_v2.12.bin bin/rk33/
    cp ${rkbin.src}/RKTRUST/RK3399TRUST.ini .
    ${run}/trust_merger --ignore-bl32 RK3399TRUST.ini

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
    platforms = [ "x86_64-linux" ];
    license = lib.licenses.unfreeRedistributable;
  };
}
