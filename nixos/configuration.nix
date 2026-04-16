# RG552 NixOS configuration
# Opinionated user config — edit this to your liking.
# Hardware specifics are in base.nix.
{ config, lib, pkgs, ... }:

{
  imports = [
    ./base.nix
  ];

  # Desktop environment
  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  # System packages
  environment.systemPackages = with pkgs; [
    vim
    htop
    file
    usbutils
    libgpiod
  ];

  # Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "yes";
  };

  # Set root password (change this!)
  users.users.root.initialPassword = "nixos";
}
