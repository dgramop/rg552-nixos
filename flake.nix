{
  description = "NixOS for Anbernic RG552 (RK3399) with ROCKNIX kernel patches";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    # SD card image for RG552
    nixosConfigurations.rg552-sdimage = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./nixos/configuration.nix
      ];
    };

    # Bare-metal test kernel image (same U-Boot layout, minimal test kernel)
    nixosConfigurations.rg552-test = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./nixos/test-configuration.nix
      ];
    };

    # Hybrid: ROCKNIX kernel + NixOS rootfs
    nixosConfigurations.rg552-hybrid = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./nixos/rocknix-hybrid-configuration.nix
      ];
    };

    # Direct access to the SD image
    packages.aarch64-linux.default = self.nixosConfigurations.rg552-sdimage.config.system.build.sdImage;

    # Also provide a convenient alias
    packages.aarch64-linux.sdImage = self.nixosConfigurations.rg552-sdimage.config.system.build.sdImage;

    # Test kernel SD image (for verifying U-Boot boot works)
    packages.aarch64-linux.testImage = self.nixosConfigurations.rg552-test.config.system.build.sdImage;

    # Hybrid SD image (ROCKNIX kernel + NixOS rootfs)
    packages.aarch64-linux.hybridImage = self.nixosConfigurations.rg552-hybrid.config.system.build.sdImage;

    # Development shell for building ROCKNIX (if needed)
    devShells.aarch64-linux.rocknix = nixpkgs.legacyPackages.aarch64-linux.callPackage ./rocknix-shell.nix {};
  };
}
