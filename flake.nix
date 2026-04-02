{
  description = "NixOS for Anbernic RG552 (RK3399) with ROCKNIX kernel";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    # NixOS configuration for RG552
    nixosConfigurations.rg552-sdimage = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./nixos/configuration.nix
      ];
    };

    # SD card image output
    packages.aarch64-linux.default = self.nixosConfigurations.rg552-sdimage.config.system.build.sdImage;
    packages.aarch64-linux.sdImage = self.nixosConfigurations.rg552-sdimage.config.system.build.sdImage;
  };
}
