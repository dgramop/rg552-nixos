# v20: Next Steps After v19 Failure

## Summary

v19 tested the Android earlycon syntax hypothesis (no baud rate) but still produced zero kernel output. This suggests the issue is deeper than just earlycon parameter formatting.

## What We've Ruled Out

1. **Earlycon baud rate specification** (v19) - Removing baud rate didn't fix it
2. **Device tree stdout-path** - Verified correct: `serial2:1500000n8`
3. **Kernel config** - Verified has `CONFIG_SERIAL_EARLYCON=y`
4. **U-Boot UART initialization** - Works correctly (U-Boot outputs fine)
5. **Memory overlap** - Fixed in v7 by moving ramdisk to 0x10000000
6. **Boot script correctness** - Verified bootargs are set correctly

## Remaining Hypotheses

### 1. Kernel Version Incompatibility (Most Likely)

**Evidence:**
- Android uses kernel 4.19.193 (works)
- We're using kernel 6.12.x (doesn't work)
- LibreELEC forum reports RK3399 boot failures with kernel 6.x
- v20 attempted to test kernel 5.15 but patches didn't apply

**Next steps:**
- Fix v20 patches for kernel 5.15
- Try kernel 6.1 LTS (patches more likely to apply than 5.15)
- As last resort: try kernel 4.19.x (exact Android match)

### 2. FIQ Console Driver Required

**Evidence:**
- Android uses `console=ttyFIQ0` not `console=ttyS2`
- FIQ (Fast Interrupt reQuest) is Rockchip-specific
- May be required for early console on RK3399

**Next steps:**
- Try `console=ttyFIQ0` in kernel params
- Check if kernel needs Rockchip FIQ console driver enabled

### 3. U-Boot → Kernel Handoff Issue

**Evidence:**
- U-Boot successfully boots and runs commands
- Kernel loads but produces zero output
- Could be issue during `booti` handoff

**Next steps:**
- Enable U-Boot debug logging (see `uboot-debug-rebuild.md`)
- Watch for errors during kernel decompression
- Check if kernel is actually being executed

### 4. UART Clock/Initialization Issue

**Evidence:**
- RK3399 uses non-standard 1500000 baud
- Kernel may not properly initialize UART at this speed
- Clock driver differences between kernel versions

**Next steps:**
- Try standard 115200 baud (requires U-Boot changes)
- Check kernel UART driver initialization code
- Compare clock driver between working/non-working kernels

## Action Plan

### Immediate (v21): Test with U-Boot Debug Logging

**Goal:** See if kernel is actually being executed

**Changes:**
1. Rebuild U-Boot with `CONFIG_LOG=y` and debug flags
2. boot.cmd already updated to set `log level 7`
3. Watch for errors during `booti` command
4. Confirm kernel decompression and execution

**Expected outcome:** Should show whether kernel is crashing silently or never executing

### Short-term (v22): Try Kernel 6.1 LTS

**Goal:** Test if newer kernel than 4.19 but older than 6.12 works

**Why 6.1 instead of 5.15:**
- 6.1 is more recent, patches more likely to apply
- Still an LTS kernel (supported until Dec 2026)
- Bridges gap between Android's 4.19 and our 6.12

**Implementation:**
```nix
boot.kernelPackages = pkgs.linuxPackagesFor (pkgs.linux_6_1.override {
  # Same patches as current, should apply more cleanly than to 5.15
});
```

### Medium-term (v23): Try FIQ Console

**Goal:** Test if Rockchip FIQ console is required

**Changes:**
1. Change `console=ttyS2,1500000n8` to `console=ttyFIQ0`
2. May need to enable FIQ console driver in kernel config
3. Check Rockchip kernel for FIQ implementation

### Last Resort: Match Android Exactly

**Goal:** Reproduce Android's exact working configuration

**Changes:**
1. Use kernel 4.19.x (same major version as Android)
2. Use `console=ttyFIQ0`
3. Remove all ROCKNIX patches, use minimal config
4. Gradually add patches back to isolate issue

## Files Modified in v20

1. **nixos/boot.cmd** - Now auto-boots and sets `log level 7`
2. **uboot-debug-rebuild.md** - Documentation for U-Boot debug logging
3. **nixos/kernel.nix** (unstaged) - Attempted switch to 5.15 (failed due to patches)

## References

- [Firefly RK3399 UART](https://wiki.t-firefly.com/en/Firefly-RK3399/driver_uart.html)
- [U-Boot Logging](https://docs.u-boot.org/en/stable/develop/logging.html)
- [RK3399 LibreELEC kernel 6.x issues](https://forum.libreelec.tv/thread/29289-rk3399-eg-nanopc-t4-has-stopped-working-after-kernel-6-x/)
