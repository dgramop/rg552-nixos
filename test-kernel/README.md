# Bare-Metal ARM64 Test Kernel for RG552

This is a minimal bare-metal ARM64 program that serves as a "hello world" test kernel. It bypasses all Linux kernel complexity and directly writes to the UART to verify that U-Boot's `booti` command works correctly.

## Purpose

This test kernel helps diagnose why the real Linux kernel produces zero output:

1. **Tests U-Boot's booti command** - Verifies U-Boot can load and execute ARM64 code
2. **Tests CPU execution** - Confirms ARM64 code runs after U-Boot handoff
3. **Tests UART hardware** - Directly writes to UART2 registers at 0xff1a0000
4. **Eliminates variables** - Removes kernel, drivers, init systems from the equation

If this test kernel works, the problem is with the real Linux kernel. If it doesn't work, the problem is with U-Boot or hardware setup.

## What It Does

The test kernel:
- Contains a proper Linux ARM64 Image header (required for `booti`)
- Loads at address 0x80000 (standard ARM64 kernel load address)
- Directly writes characters to UART2 transmit holding register
- Prints a message confirming successful execution
- Enters an infinite loop (WFE instruction)

## Prerequisites

You need an ARM64 cross-compiler:

```bash
# macOS with Homebrew
brew install aarch64-elf-gcc

# Or use the Linux toolchain
brew install aarch64-linux-gnu-binutils aarch64-linux-gnu-gcc

# NixOS/Nix
nix-shell -p pkgsCross.aarch64-multiplatform.buildPackages.gcc
```

## Building

```bash
cd test-kernel
make
```

This produces `Image` - a bare-metal binary that U-Boot can load with `booti`.

## Testing on RG552

### Method 1: Replace kernel on SD card

1. Build the test kernel: `make`
2. Mount your NixOS SD card firmware partition
3. Backup the real kernel: `cp /path/to/firmware/Image /path/to/firmware/Image.backup`
4. Copy test kernel: `cp Image /path/to/firmware/Image`
5. Boot the RG552 with serial console connected
6. Watch for the test message on serial

### Method 2: Manual load in U-Boot

1. Copy `Image` to the firmware partition as `test-kernel`
2. Boot RG552 and interrupt U-Boot (press a key during countdown)
3. Load test kernel manually:
   ```
   load mmc 1:1 ${kernel_addr_r} /test-kernel
   booti ${kernel_addr_r} - ${fdt_addr_r}
   ```

### Method 3: TFTP (if you have network boot setup)

```bash
# On your TFTP server
cp Image /tftpboot/

# In U-Boot
dhcp
tftp ${kernel_addr_r} Image
booti ${kernel_addr_r} - ${fdt_addr_r}
```

## Expected Output

If successful, you should see on the serial console:

```
***********************************
*** BARE METAL TEST KERNEL ***
***********************************

If you see this, U-Boot booti works!
The problem is with the real kernel.
```

## Interpretation of Results

### Success: You see the test message

- **U-Boot's booti command works correctly**
- **UART hardware is accessible from ARM64 code**
- **The problem is specifically with the Linux kernel**

Next steps:
- Kernel version issue (try older kernel like 6.1 LTS or 4.19)
- Kernel configuration issue
- Kernel early boot code incompatibility with RK3399

### Failure: No output at all

- **U-Boot may not be transferring control properly**
- **CPU may not be executing the code**
- **Cache/MMU issues**

Next steps:
- Enable U-Boot debug logging (see `../uboot-debug-rebuild.md`)
- Check U-Boot's `booti` implementation
- Verify load addresses are correct

### Partial output or garbled text

- **UART is working but has initialization issues**
- **Baud rate mismatch** (unlikely since U-Boot works fine)
- **Race condition in UART access**

## Technical Details

### Memory Layout

- Load address: 0x80000 (standard for ARM64)
- Code is position-independent for this address
- No MMU, no caches - bare metal execution

### UART Access

Directly writes to RK3399 UART2 registers:
- Base: 0xff1a0000
- THR (Transmit Holding Register): +0x00
- LSR (Line Status Register): +0x14
  - Bit 5 (THRE): Transmit Holding Register Empty

The code polls LSR until THRE=1, then writes each character to THR.

### ARM64 Image Header

The first 64 bytes conform to Linux ARM64 Image format:
- Offset 0x00: Branch instruction to code
- Offset 0x38: Magic "ARM\x64"

This allows U-Boot's `booti` to recognize and load it correctly.

## Troubleshooting Build

### "command not found: aarch64-linux-gnu-as"

Install ARM64 toolchain (see Prerequisites section).

### "cannot find -lc" or similar linker errors

This is a bare-metal program - we don't link against libc. The Makefile uses `ld` directly to avoid this.

### Build succeeds but file is huge

The `Image` file should be very small (< 4KB). If it's large:
```bash
# Check the actual binary
ls -lh Image

# It should be around 1-2KB
```

If it's much larger, check that `objcopy -O binary` worked correctly.

## Cleaning Up

```bash
# Remove built files
make clean

# Restore real kernel (if you replaced it)
cp /path/to/firmware/Image.backup /path/to/firmware/Image
```

## Notes

- This test kernel does NOT boot a real operating system
- It only proves that U-Boot → ARM64 execution → UART works
- After printing the message, it enters an infinite loop (WFE)
- No initrd is needed (we pass `-` to `booti` for the initrd address)
- The device tree is still loaded but not used by this test kernel
