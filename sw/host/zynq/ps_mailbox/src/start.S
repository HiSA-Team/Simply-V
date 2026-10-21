// Author: Federica Sarnataro
// Description: Minimal startup for the Cortex-A9 #0, loaded and started by XSDB.
//   Interrupts off, stack, clear .bss, call main, then wait forever.

    .section .text.boot, "ax"
    .arm
    .global _start
_start:
    cpsid   if                  // Mask IRQ and FIQ
    ldr     sp, =__stack_top    // Stack in DDR (see ps.ld)

    // Clear .bss
    ldr     r0, =__bss_start
    ldr     r1, =__bss_end
    mov     r2, #0
1:  cmp     r0, r1
    strlo   r2, [r0], #4
    blo     1b

    bl      main

    // Done: stay here
2:  wfe
    b       2b
