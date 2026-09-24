{ config, lib, pkgs, ... }:

{
  networking.hostName = lib.mkDefault "rg552";
  networking.networkmanager.enable = lib.mkDefault true;
  networking.useDHCP = lib.mkDefault false;
  networking.firewall.enable = lib.mkDefault false;

  systemd.services."serial-getty@ttyS2" = {
    enable = lib.mkDefault true;
    wantedBy = [ "getty.target" ];
  };

  services.xserver.enable = lib.mkDefault true;
  services.displayManager.ly.enable = lib.mkDefault true;
  services.xserver.desktopManager.xfce.enable = lib.mkDefault true;

  services.openssh = {
    enable = lib.mkDefault true;
    settings.PermitRootLogin = lib.mkDefault "yes";
  };

  users.users.root.initialPassword = lib.mkDefault "nixos";

  environment.systemPackages = with pkgs; [
    vim
    htop
    file
    usbutils
    libgpiod
  ];

  nix.settings.experimental-features = lib.mkDefault [ "nix-command" "flakes" ];

  system.stateVersion = lib.mkDefault "24.11";
}
