{ stdenv }:

stdenv.mkDerivation {
  pname = "rocknix-rg552-kernel";
  version = "unknown";

  # Use the ROCKNIX kernel files extracted from their image
  src = ../rocknix-kernel;

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    mkdir -p $out

    # Copy kernel Image (ROCKNIX calls it KERNEL, we call it Image)
    cp KERNEL $out/Image

    # Copy device tree
    mkdir -p $out/dtbs
    cp rk3399-anbernic-rg552.dtb $out/dtbs/
  '';

  meta = {
    description = "ROCKNIX kernel for RG552 (known working)";
    platforms = [ "aarch64-linux" ];
  };
}
