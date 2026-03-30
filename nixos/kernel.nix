# Custom kernel for RG552 with ROCKNIX patches
{ pkgs, lib, ... }:

{
  boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_latest.override {
    argsOverride = {
      # Use the base kernel config
      src = pkgs.linux_latest.src;
      version = pkgs.linux_latest.version;
      modDirVersion = pkgs.linux_latest.modDirVersion;

      # Kernel config overrides for serial console debugging
      structuredExtraConfig = with lib.kernel; {
        # Enable early console support
        SERIAL_EARLYCON = yes;
        SERIAL_8250_CONSOLE = yes;
        SERIAL_OF_PLATFORM = yes;
        # Enable all console output
        PRINTK = yes;
        # Note: EARLY_PRINTK was removed in newer kernels, using SERIAL_EARLYCON instead
      };

      # Apply ROCKNIX patches for RG552 hardware support
      kernelPatches = (pkgs.linux_latest.kernelPatches or []) ++ [
        # Device tree and base RG552 support
        {
          name = "anbernic-rg552";
          patch = ../kernel-patches/000-anbernic-rg552.patch;
        }
        # Sharp LS054B3SX01 display panel driver
        {
          name = "panel-sharp-ls054b3sx01";
          patch = ../kernel-patches/002-panel-sharp-ls054b3sx01.patch;
        }
        # RK3399 OPP (operating performance points) improvements
        {
          name = "rk3399-opp";
          patch = ../kernel-patches/001-rk3399-opp.patch;
        }
        # RK crypto fix
        {
          name = "rk-crypto-fix";
          patch = ../kernel-patches/001-rk_crypto-fix-ahash-sg-fallback.patch;
        }
        # Battery driver name fix
        {
          name = "battery-name";
          patch = ../kernel-patches/004-battery-name.patch;
        }
        # Mali GPU (Midgard) support
        {
          name = "mali-midgard";
          patch = ../kernel-patches/006-mali-midgard.patch;
        }
        # CPU NVMEM support
        {
          name = "enable-cpu-nvmem";
          patch = ../kernel-patches/007-enable-cpu-nvmem.patch;
        }
        # Set default fan speed on boot
        {
          name = "set-boot-fanspeed";
          patch = ../kernel-patches/998-set-boot-fanspeed.patch;
        }
        # Reduce kernel log spam
        {
          name = "clear-log-spam";
          patch = ../kernel-patches/999-clear-log-spam.patch;
        }
      ];

      # Don't override any kernel config - let it use defaults
      # The patches add the necessary Kconfig options
    };
  });
}
