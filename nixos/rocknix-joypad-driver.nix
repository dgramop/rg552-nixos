{ lib, stdenv, kernel, fetchFromGitHub }:

stdenv.mkDerivation rec {
  pname = "rocknix-joypad";
  version = "7647fdb0fc89cd69b284903bf7707e861df5dc7e";

  src = fetchFromGitHub {
    owner = "ROCKNIX";
    repo = "rocknix-joypad";
    rev = version;
    sha256 = "sha256-6gskpAYxnxygMxm3+mrg24XbZmV1X40wC3/7EGwXUqQ=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;

  makeFlags = kernel.makeFlags ++ [
    "KERNEL_SRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    "INSTALL_MOD_PATH=${placeholder "out"}"
  ];

  buildPhase = ''
    runHook preBuild
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build M=$(pwd) modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build M=$(pwd) INSTALL_MOD_PATH=$out modules_install
    runHook postInstall
  '';

  meta = with lib; {
    description = "ROCKNIX joypad driver for RG552 and other handheld devices";
    homepage = "https://github.com/ROCKNIX/rocknix-joypad";
    license = licenses.gpl2Only;
    platforms = platforms.linux;
    maintainers = [];
  };
}
