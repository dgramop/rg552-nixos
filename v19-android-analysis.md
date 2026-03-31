# v19: Android Boot Log Analysis

## Key Discovery: earlycon Syntax Difference

Analyzing the Android boot log revealed critical differences in how Android configures earlycon.

### Android's Configuration (Working)

```
earlycon=uart8250,mmio32,0xff1a0000
```

Key points:
- **NO baud rate specified** in earlycon parameter
- The kernel inherits the baud rate from U-Boot's UART configuration
- Console parameter: `console=ttyFIQ0` (not ttyS2!)
- Kernel version: 4.19.193
- Boot log shows: `bootconsole [uart8250] enabled` and `(options '')`

### NixOS v1-v18 Configuration (Not Working)

```
earlycon=uart8250,mmio32,0xff1a0000,1500000n8
```

Key points:
- Baud rate explicitly specified: `1500000n8`
- Console parameter: `console=ttyS2,1500000n8`
- Kernel version: 6.12.x (linux_latest)
- **Zero kernel output** on serial console

## What We Verified Before This

All of these were correct:
- ✓ Kernel has CONFIG_SERIAL_EARLYCON=y compiled in
- ✓ Device tree stdout-path is `serial2:1500000n8`
- ✓ U-Boot successfully outputs to the same serial port at 1500000 baud
- ✓ bootargs correctly set without corruption

Despite everything being "correct" according to documentation, the kernel produced no output.

## v19 Change

Modified `nixos/sd-image-rg552.nix` line 103:
```nix
# Before (v18):
"earlycon=uart8250,mmio32,0xff1a0000,1500000n8"

# After (v19):
"earlycon=uart8250,mmio32,0xff1a0000"  # No baud rate - inherit from U-Boot
```

## Hypothesis

The explicit baud rate in the earlycon parameter may be:
1. Using incorrect syntax for this UART driver version
2. Causing the earlycon initialization to fail silently
3. Incompatible with how kernel 6.12 parses earlycon parameters

By using Android's working syntax, we let the kernel inherit the UART configuration that U-Boot already set up correctly.

## Additional Observations from Android

1. **ttyFIQ0 vs ttyS2**: Android uses FIQ (Fast Interrupt reQuest) based console
   - This is Rockchip-specific
   - May explain some differences, but earlycon should still work with uart8250

2. **Kernel version gap**: Android uses 4.19.193, we use 6.12.x
   - Possible regression in newer kernels?
   - Or change in earlycon parameter parsing?

## Next Steps if v19 Works

If removing the baud rate fixes earlycon:
1. Document this as RK3399-specific requirement
2. Consider if we should also try `console=ttyFIQ0`
3. Investigate if this is a kernel bug that should be reported

## Next Steps if v19 Doesn't Work

If this doesn't fix it:
1. Try older kernel version (5.x or 4.19.x to match Android)
2. Investigate FIQ console driver requirements
3. Consider comparing kernel configs more thoroughly with Android
4. May need JTAG or other debugging approaches
