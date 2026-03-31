# Recompiling U-Boot with Debug Logging

The current U-Boot binary (`nixos/u-boot-rockchip.bin`) may not have logging support compiled in. To get detailed debug output from U-Boot, you need to rebuild it with logging enabled.

## U-Boot Logging System

U-Boot has a comprehensive logging system with these log levels:

| Level | Name | Value | Description |
|-------|------|-------|-------------|
| LOGL_EMERG | Emergency | 0 | System is unusable |
| LOGL_ALERT | Alert | 1 | Action must be taken immediately |
| LOGL_CRIT | Critical | 2 | Critical conditions |
| LOGL_ERR | Error | 3 | Error conditions |
| LOGL_WARNING | Warning | 4 | Warning conditions |
| LOGL_NOTICE | Notice | 5 | Normal but significant |
| LOGL_INFO | Info | 6 | Informational messages |
| LOGL_DEBUG | Debug | 7 | Debug-level messages |
| LOGL_DEBUG_CONTENT | Debug Content | 8 | Debug message content |
| LOGL_DEBUG_IO | Debug I/O | 9 | Debug hardware I/O |

## Required Kconfig Options

To enable full debug logging in U-Boot, add these options to the RK3399 defconfig:

```kconfig
# Enable logging system
CONFIG_LOG=y

# Enable console output for logs
CONFIG_LOG_CONSOLE=y

# Set maximum log level to DEBUG (7)
# This includes all debug() calls in the build
CONFIG_LOG_MAX_LEVEL=7

# Set default log level to INFO (6)
# Can be changed at runtime with "log level" command
CONFIG_LOG_DEFAULT_LEVEL=6

# Enable the log command for runtime control
CONFIG_CMD_LOG=y
```

## Build Impact

**Warning:** Setting `CONFIG_LOG_MAX_LEVEL=7` significantly increases binary size:
- ~49KB additional rodata
- ~98KB additional text
- This may cause U-Boot to exceed size limits on some platforms

If size is a concern, you can:
1. Set `CONFIG_LOG_MAX_LEVEL=6` (INFO) for less verbose output
2. Only enable logging for SPL/TPL if needed
3. Disable logging after debugging

## How to Rebuild U-Boot for RG552

### Option 1: Use get-bootloader.sh Script

The existing `get-bootloader.sh` script downloads the RG552 U-Boot from the vendor. To rebuild with debug flags, you need to:

1. Extract the U-Boot source or defconfig from the vendor
2. Modify the defconfig to add logging options
3. Rebuild U-Boot with ARM64 toolchain

### Option 2: Manual Rebuild Process

```bash
# 1. Get the RK3399 U-Boot source (vendor or mainline)
git clone https://github.com/rockchip-linux/u-boot.git -b stable-4.19-rk3399
cd u-boot

# 2. Find the RG552 defconfig (or closest match like evb-rk3399)
# The RG552 likely uses a custom defconfig from the vendor
ls configs/*rk3399*

# 3. Load the base config
make evb-rk3399_defconfig  # or rg552-specific defconfig if it exists

# 4. Enable logging options
cat >> .config << EOF
CONFIG_LOG=y
CONFIG_LOG_CONSOLE=y
CONFIG_LOG_MAX_LEVEL=7
CONFIG_LOG_DEFAULT_LEVEL=6
CONFIG_CMD_LOG=y
EOF

# 5. Build with ARM64 toolchain
export CROSS_COMPILE=aarch64-linux-gnu-
export BL31=path/to/trusted-firmware-a/build/rk3399/release/bl31/bl31.elf
make -j$(nproc)

# 6. The output will be u-boot-rockchip.bin
cp u-boot-rockchip.bin /path/to/rg552/nixos/u-boot-rockchip.bin
```

### Option 3: Use NixOS to Build U-Boot

You could add a U-Boot package to the flake that builds with debug flags:

```nix
# Add to flake.nix
ubootRG552Debug = pkgs.buildUBoot rec {
  defconfig = "evb-rk3399_defconfig";  # or RG552-specific
  extraMeta.platforms = ["aarch64-linux"];
  BL31 = "${pkgs.armTrustedFirmwareRK3399}/bl31.elf";

  # Enable debug logging
  extraConfig = ''
    CONFIG_LOG=y
    CONFIG_LOG_CONSOLE=y
    CONFIG_LOG_MAX_LEVEL=7
    CONFIG_LOG_DEFAULT_LEVEL=6
    CONFIG_CMD_LOG=y
  '';

  filesToInstall = ["u-boot-rockchip.bin"];
};
```

## Runtime Log Control

Once U-Boot is rebuilt with logging support, you can control it from the boot script (`nixos/boot.cmd`):

```bash
# Set log level to DEBUG (7) - already added to boot.cmd
log level 7

# Or set to INFO (6) for less verbose output
log level 6

# View current log settings
log status

# Add filters (if needed)
log filter-add -c mmc -L 7      # Enable DEBUG for MMC category
log filter-add -c blk -L 7      # Enable DEBUG for block device category
```

## What This Will Show

With debug logging enabled, you'll see detailed output from:

- MMC/SD card initialization
- Device tree parsing
- Memory allocation
- File system operations (load commands)
- booti kernel boot process
- **Critically:** Any errors or warnings during kernel handoff

This should help identify why the kernel produces no output after U-Boot hands control to it.

## Current Status

The `nixos/boot.cmd` file has been updated to set `log level 7` (DEBUG), but this will only work if U-Boot was compiled with `CONFIG_LOG=y`.

If you see "Unknown command 'log'" when booting, that confirms U-Boot needs to be rebuilt with logging support.

## References

- [U-Boot Logging Documentation](https://docs.u-boot.org/en/stable/develop/logging.html)
- [U-Boot Logging Implementation](https://github.com/u-boot/u-boot/blob/master/doc/develop/logging.rst)
- [U-Boot Log Header](https://github.com/u-boot/u-boot/blob/master/include/log.h)
