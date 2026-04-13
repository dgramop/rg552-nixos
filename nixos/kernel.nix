{ lib, buildLinux, fetchurl, ... } @ args:

let
  # Linux kernel version matching ROCKNIX
  version = "6.18.20";

  # Kernel patches in correct application order
  # Mainline patches MUST be applied first (they provide base functionality)
  # Then RK3399-specific patches (which depend on mainline changes)
  kernelPatches = [
    # Mainline patches (5)
    { name = "gpiolib-of-revert"; patch = ../kernel-patches/mainline/0001-gpiolib-of-revert-api-changes-needed-for-joypad-driv.patch; }
    { name = "input-polldev"; patch = ../kernel-patches/mainline/0002-input-add-input-polldev-driver.patch; }
    { name = "pwm-set-period"; patch = ../kernel-patches/mainline/0003-pwm-add-pwm_set_period.patch; }
    { name = "adc-keys-redirect"; patch = ../kernel-patches/mainline/0004-input-adc-keys-redirect-keycode-316-to-rocknix-joypa.patch; }
    { name = "rtl8733bu-bluetooth"; patch = ../kernel-patches/mainline/0005-Bluetooth-btrtl-Add-the-support-for-RTL8733BU.patch; }

    # RK3399 device-specific patches (9)
    # NOTE: 000-anbernic-rg552.patch adds the device tree source file
    { name = "rg552-device-tree"; patch = ../kernel-patches/rk3399/000-anbernic-rg552.patch; }
    { name = "rk-crypto-fix"; patch = ../kernel-patches/rk3399/001-rk_crypto-fix-ahash-sg-fallback.patch; }
    { name = "rk3399-opp"; patch = ../kernel-patches/rk3399/001-rk3399-opp.patch; }
    { name = "sharp-panel"; patch = ../kernel-patches/rk3399/002-panel-sharp-ls054b3sx01.patch; }
    { name = "battery-name"; patch = ../kernel-patches/rk3399/004-battery-name.patch; }
    { name = "mali-midgard"; patch = ../kernel-patches/rk3399/006-mali-midgard.patch; }
    { name = "cpu-nvmem"; patch = ../kernel-patches/rk3399/007-enable-cpu-nvmem.patch; }
    { name = "boot-fanspeed"; patch = ../kernel-patches/rk3399/998-set-boot-fanspeed.patch; }
    { name = "clear-log-spam"; patch = ../kernel-patches/rk3399/999-clear-log-spam.patch; }
  ];

in buildLinux (args // {
  inherit version kernelPatches;

  # Kernel source from kernel.org
  src = fetchurl {
    url = "mirror://kernel/linux/kernel/v6.x/linux-${version}.tar.xz";
    sha256 = "sha256-g3pavZjkYHigrhQA4tqtiezkXMMgkDewnCJl2rI5NVM=";
  };

  # Use ROCKNIX kernel configuration directly
  configfile = ./rocknix-kernel.config;

  # Kernel build configuration
  modDirVersion = version;

  # Make configuration non-interactive
  autoModules = false;

  # Many ROCKNIX config options don't exist in mainline - ignore those
  # But use structuredExtraConfig to FORCE critical drivers to be enabled
  ignoreConfigErrors = true;

  # Force critical drivers that ignoreConfigErrors might silently disable
  structuredExtraConfig = with lib.kernel; {
    DRM = yes;
    DRM_ROCKCHIP = yes;
    DRM_DW_MIPI_DSI = yes;
    DRM_PANEL_SHARP_LS054B3SX01 = yes;
    DRM_PANFROST = yes;

    # WiFi (RTL8821CS via SDIO) — Kconfig auto-selects RTW88_SDIO, RTW88_CORE
    RTW88_8821CS = module;
  };

  # Extra metadata
  extraMeta = {
    branch = "6.18";
    description = "Linux kernel for Anbernic RG552 (RK3399) with ROCKNIX patches";
    platforms = [ "aarch64-linux" ];
    maintainers = [ ];
    # This is a long build - expect 2-4 hours on first build
    timeout = 14400; # 4 hours
  };
} // (args.argsOverride or {}))
