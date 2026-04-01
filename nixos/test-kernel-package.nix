{ stdenv, ubootTools }:

stdenv.mkDerivation {
  pname = "rg552-bare-metal-test-kernel";
  version = "1.0";

  src = ../test-kernel;

  nativeBuildInputs = [ ubootTools ];

  buildPhase = ''
    # Assemble the test kernel
    ${stdenv.cc.targetPrefix}as -o hello.o hello.S

    # Link with custom linker script
    ${stdenv.cc.targetPrefix}ld -T linker.ld -o hello.elf hello.o

    # Extract raw binary (ARM64 Image format)
    ${stdenv.cc.targetPrefix}objcopy -O binary hello.elf Image

    # Compile boot script
    mkimage -A arm64 -O linux -T script -C none -d test-boot.cmd test-boot.scr
  '';

  installPhase = ''
    mkdir -p $out
    cp Image $out/
    cp test-boot.scr $out/boot.scr

    # Also copy for reference
    cp hello.elf $out/
  '';

  meta = {
    description = "Bare-metal ARM64 test kernel for RG552 to verify U-Boot booti";
    platforms = [ "aarch64-linux" ];
  };
}
