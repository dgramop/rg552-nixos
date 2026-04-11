{
  description = "NixOS for Anbernic RG552 (RK3399)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosConfigurations.rg552-sdimage = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = {
        # x86_64 glibc for qemu user-mode emulation of rkbin tools
        glibc-x86 = (import nixpkgs { system = "x86_64-linux"; }).glibc;
      };
      modules = [
        ./nixos/configuration-built-kernel.nix
      ];
    };

    packages.aarch64-linux = {
      default = self.nixosConfigurations.rg552-sdimage.config.system.build.sdImage;

      sdImage = self.nixosConfigurations.rg552-sdimage.config.system.build.sdImage;

      # Standalone kernel package (builds Linux 6.18.20 with ROCKNIX patches)
      kernel = let
        pkgs = import nixpkgs { system = "aarch64-linux"; };
      in pkgs.callPackage ./nixos/kernel-build-package.nix {
        inherit (pkgs.linuxKernel) buildLinux;
      };

      # Standalone U-Boot package
      uboot = let
        pkgs = import nixpkgs { system = "aarch64-linux"; };
      in pkgs.callPackage ./nixos/uboot-package.nix {
        inherit (pkgs) buildUBoot armTrustedFirmwareRK3399 rkbin qemu;
      };
    };
  };
}
