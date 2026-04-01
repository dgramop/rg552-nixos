/* Minimal ARM64 bare-metal program that writes to RK3399 UART2
 *
 * This is a test "kernel" to verify:
 * - U-Boot's booti command works
 * - We can execute ARM64 code after handoff
 * - We can write to UART2 at 0xff1a0000
 *
 * UART is already initialized by U-Boot at 1500000 baud.
 * We just need to write characters to the transmit holding register.
 */

.section ".text.boot"

/* Linux ARM64 Image header - required for booti command */
.global _start
_start:
    b       do_boot                 // branch to code
    .long   0                       // reserved
    .quad   _kernel_size            // Image size (will be filled by linker)
    .quad   0                       // flags
    .quad   0                       // reserved
    .quad   0                       // reserved
    .quad   0                       // reserved
    .ascii  "ARM\x64"                // Magic number
    .long   0                       // reserved

do_boot:
    /* UART2 base address: 0xff1a0000
     * Registers:
     * +0x00: RBR/THR/DLL (Receive/Transmit/Divisor Latch Low)
     * +0x14: LSR (Line Status Register)
     *   bit 5 = THRE (Transmit Holding Register Empty)
     *   bit 6 = TEMT (Transmitter Empty)
     */

    // Load UART base address into x0
    mov     x0, #0xff1a0000
    movk    x0, #0xff1a, lsl #16

    // Message to print: "*** BARE METAL TEST KERNEL ***\r\n"
    adr     x1, message             // Load message address

print_loop:
    ldrb    w2, [x1], #1           // Load byte from message, increment pointer
    cbz     w2, hang               // If null terminator, stop

wait_tx_ready:
    // Wait for UART to be ready (LSR bit 5 = THRE)
    ldr     w3, [x0, #0x14]        // Load LSR register
    tst     w3, #0x20              // Test bit 5 (THRE)
    b.eq    wait_tx_ready          // If not ready, wait

    // Write character to UART
    strb    w2, [x0]               // Write to THR register
    b       print_loop             // Continue with next character

hang:
    // Infinite loop - successfully printed message
    wfe                             // Wait for event (low power)
    b       hang

message:
    .ascii  "\r\n"
    .ascii  "***********************************\r\n"
    .ascii  "*** BARE METAL TEST KERNEL ***\r\n"
    .ascii  "***********************************\r\n"
    .ascii  "\r\n"
    .ascii  "If you see this, U-Boot booti works!\r\n"
    .ascii  "The problem is with the real kernel.\r\n"
    .ascii  "\r\n"
    .byte   0                       // Null terminator

.align 12                          // Align to page boundary

_kernel_size = . - _start
