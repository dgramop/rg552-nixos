{
  description = "NixOS for Anbernic RG552 (RK3399) with ROCKNIX kernel";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    plymouth-lite.url = "git+file:../rg552-plymouth";
  };

  outputs = { self, nixpkgs, plymouth-lite }: {
    # NixOS configuration for RG552 with prebuilt ROCKNIX kernel (FAST)
    nixosConfigurations.rg552-sdimage = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        plymouth-lite.nixosModules.default
        ./nixos/configuration.nix
      ];
    };

    # NixOS configuration for RG552 with BUILT kernel from source (SLOW)
    nixosConfigurations.rg552-sdimage-built = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        plymouth-lite.nixosModules.default
        ./nixos/configuration-built-kernel.nix
      ];
    };

    packages.aarch64-linux = {
      # Default: SD image with built kernel (customizable)
      default = self.nixosConfigurations.rg552-sdimage-built.config.system.build.sdImage;

      # SD image with built kernel from source (slow ~3-4 hour builds, but customizable)
      sdImage = self.nixosConfigurations.rg552-sdimage-built.config.system.build.sdImage;

      # SD image with prebuilt ROCKNIX kernel (fast ~10 min builds)
      sdImageRocknix = self.nixosConfigurations.rg552-sdimage.config.system.build.sdImage;

      # Standalone kernel package (builds Linux 6.18.20 with ROCKNIX patches)
      kernel = let
        pkgs = import nixpkgs { system = "aarch64-linux"; };
      in pkgs.callPackage ./nixos/kernel-build-package.nix {
        inherit (pkgs.linuxKernel) buildLinux;
      };
    };
  };
}
