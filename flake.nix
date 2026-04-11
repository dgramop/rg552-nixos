{
  description = "NixOS for Anbernic RG552 (RK3399)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    pkgs-arm = import nixpkgs { system = "aarch64-linux"; };
    pkgs-x86 = import nixpkgs { system = "x86_64-linux"; config.allowUnfree = true; };

    # U-Boot compilation (aarch64)
    ubootDrv = pkgs-arm.callPackage ./nixos/uboot.nix {
      inherit (pkgs-arm) buildUBoot armTrustedFirmwareRK3399;
    };

    # Bootloader assembly with rkbin tools (x86_64)
    uboot = pkgs-x86.callPackage ./nixos/uboot-rockchip.nix {
      inherit (pkgs-x86) rkbin;
      inherit ubootDrv;
    };
  in {
    nixosConfigurations.rg552-sdimage = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      specialArgs = { inherit uboot; };
      modules = [
        ./nixos/configuration.nix
      ];
    };

    packages.aarch64-linux = {
      default = self.nixosConfigurations.rg552-sdimage.config.system.build.sdImage;
      sdImage = self.nixosConfigurations.rg552-sdimage.config.system.build.sdImage;

      kernel = pkgs-arm.callPackage ./nixos/kernel.nix {
        inherit (pkgs-arm.linuxKernel) buildLinux;
      };
    };

    packages.x86_64-linux = {
      inherit uboot;
    };
  };
}
