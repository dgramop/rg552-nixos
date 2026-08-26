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
    { name = "rocknix-joypad"; patch = ../kernel-patches/mainline/0006-input-add-rocknix-joypad-driver.patch; }

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

in (buildLinux (args // {
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

    # WiFi (RTL8188FTV via USB)
    RTL8XXXU = module;

    # nftables for NixOS firewall
    NF_TABLES = module;
    NF_TABLES_INET = yes;
    NF_TABLES_NETDEV = yes;
    NF_TABLES_IPV4 = yes;
    NF_TABLES_IPV6 = yes;
    NFT_COMPAT = module;
    NFT_CT = module;
    NFT_LOG = module;
    NFT_LIMIT = module;
    NFT_REJECT = module;
    NFT_NAT = module;
    NFT_MASQ = module;

    NETFILTER_XT_MATCH_PKTTYPE = module;
    NETFILTER_XT_MATCH_RPFILTER = module;
    IP_NF_MATCH_RPFILTER = module;
    IP6_NF_MATCH_RPFILTER = module;
    NETFILTER_XT_MATCH_STATE = module;
    NETFILTER_XT_MATCH_CONNTRACK = module;
    NETFILTER_XT_MATCH_MULTIPORT = module;
    NETFILTER_XT_MATCH_ADDRTYPE = module;
    NETFILTER_XT_MATCH_TCPMSS = module;
    NETFILTER_XT_MATCH_LIMIT = module;
    NETFILTER_XT_MATCH_COMMENT = module;
    NETFILTER_XT_TARGET_REJECT = module;
    NETFILTER_XT_TARGET_LOG = module;
    IP_NF_FILTER = module;
    IP_NF_TARGET_REJECT = module;
    IP6_NF_FILTER = module;
    IP6_NF_TARGET_REJECT = module;
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
} // (args.argsOverride or {}))).overrideAttrs (old: {
  # Rebind the D-pad + a few triggers/face-buttons in the DT so the joypad
  # emits keyboard codes for desktop navigation.
  postPatch = (old.postPatch or "") + ''
    substituteInPlace arch/arm64/boot/dts/rockchip/rk3399-anbernic-rg552.dts \
      --replace-fail 'linux,code = <BTN_DPAD_UP>;'    'linux,code = <KEY_UP>;' \
      --replace-fail 'linux,code = <BTN_DPAD_DOWN>;'  'linux,code = <KEY_DOWN>;' \
      --replace-fail 'linux,code = <BTN_DPAD_LEFT>;'  'linux,code = <KEY_LEFT>;' \
      --replace-fail 'linux,code = <BTN_DPAD_RIGHT>;' 'linux,code = <KEY_RIGHT>;' \
      --replace-fail 'linux,code = <BTN_EAST>;'       'linux,code = <KEY_ESC>;' \
      --replace-fail 'linux,code = <BTN_SOUTH>;'      'linux,code = <KEY_BACKSPACE>;' \
      --replace-fail 'linux,code = <BTN_WEST>;'       'linux,code = <KEY_SPACE>;' \
      --replace-fail 'linux,code = <BTN_NORTH>;'      'linux,code = <KEY_DELETE>;' \
      --replace-fail 'linux,code = <BTN_START>;'      'linux,code = <KEY_LEFTMETA>;' \
      --replace-fail 'linux,code = <BTN_SELECT>;'     'linux,code = <KEY_HOME>;' \
      --replace-fail 'linux,code = <BTN_TL>;'         'linux,code = <KEY_ENTER>;' \
      --replace-fail 'linux,code = <BTN_TR>;'         'linux,code = <KEY_TAB>;' \
      --replace-fail 'linux,code = <BTN_TL2>;'        'linux,code = <KEY_PAGEUP>;' \
      --replace-fail 'linux,code = <BTN_TR2>;'        'linux,code = <KEY_PAGEDOWN>;'
  '';

  # linuxManualConfig oldconfig runs against unpatched source and strips
  # symbols added by our patches. Re-inject after configure, before build.
  postConfigure = (old.postConfigure or "") + ''
    cp -L $buildRoot/.config $buildRoot/.config.tmp
    rm $buildRoot/.config
    mv $buildRoot/.config.tmp $buildRoot/.config
    chmod +w $buildRoot/.config
    # adc-keys defines joypad_input_g and must be built-in to be visible to
    # the built-in rocknix-singleadc-joypad driver.
    sed -i 's/^CONFIG_KEYBOARD_ADC=m$/CONFIG_KEYBOARD_ADC=y/' $buildRoot/.config
    echo CONFIG_INPUT_POLLDEV=y >> $buildRoot/.config
    echo CONFIG_KEYBOARD_ADC=y >> $buildRoot/.config
    echo CONFIG_ROCKNIX_SINGLEADC_JOYPAD=y >> $buildRoot/.config
    make "''${makeFlags[@]}" olddefconfig
  '';
})
