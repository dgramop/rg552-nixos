# Minimal NixOS configuration for RG552
{ config, pkgs, lib, ... }:

{
  imports = [
    ./sd-image-rg552.nix
  ];

  # Minimal packages
  environment.systemPackages = with pkgs; [
    vim
    htop
    file
  ];

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  # Set root password (change this!)
  users.users.root.initialPassword = "nixos";

  # Networking
  networking = {
    hostName = "rg552";
    useDHCP = false;
    interfaces.eth0.useDHCP = lib.mkDefault true;
    wireless.enable = lib.mkDefault false;  # Enable if you have WiFi working
  };

  system.stateVersion = "24.11";
}
