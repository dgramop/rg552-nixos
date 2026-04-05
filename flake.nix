{
  description = "NixOS for Anbernic RG552 (RK3399) with ROCKNIX kernel";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    # NixOS configuration for RG552 with prebuilt ROCKNIX kernel (FAST)
    nixosConfigurations.rg552-sdimage = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./nixos/configuration.nix
      ];
    };

    # NixOS configuration for RG552 with BUILT kernel from source (SLOW)
    nixosConfigurations.rg552-sdimage-built = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./nixos/configuration-built-kernel.nix
      ];
    };

    # TEMPORARY TEST: Hybrid with prebuilt kernel Image + built DTB
    nixosConfigurations.rg552-sdimage-hybrid = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./nixos/tmp-test-prebuilt-kernel-with-built-dtb.nix
      ];
    };

    packages.aarch64-linux = {
      # Default: SD image with prebuilt kernel (fast ~10 min builds)
      default = self.nixosConfigurations.rg552-sdimage.config.system.build.sdImage;

      # SD image with prebuilt ROCKNIX kernel (fast ~10 min builds)
      sdImage = self.nixosConfigurations.rg552-sdimage.config.system.build.sdImage;

      # Standalone kernel package (builds Linux 6.18.20 with ROCKNIX patches)
      # First build will fail with hash mismatch - update kernel-build-package.nix with correct hash
      kernel = let
        pkgs = import nixpkgs { system = "aarch64-linux"; };
      in pkgs.callPackage ./nixos/kernel-build-package.nix {
        inherit (pkgs.linuxKernel) buildLinux;
      };

      # SD image with BUILT kernel from source (slow ~3-4 hour builds, but customizable)
      sdImageBuilt = self.nixosConfigurations.rg552-sdimage-built.config.system.build.sdImage;

      # TEMPORARY TEST: Hybrid image with prebuilt kernel Image + built DTB (for debugging)
      hybridImage = self.nixosConfigurations.rg552-sdimage-hybrid.config.system.build.sdImage;
    };
  };
}
