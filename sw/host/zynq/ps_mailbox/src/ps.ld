/* Author: Federica Sarnataro */
/* Description: Linker script for the PS side of the mailbox test.
 *   Program in DDR at 0x0010_0000 (initialized by ps7_init), like the
 *   Xilinx bare-metal apps. The test result is at a fixed address, so
 *   XSDB can read it with mrd (see main.c). */

ENTRY(_start)

MEMORY
{
    DDR (rwx) : ORIGIN = 0x00100000, LENGTH = 0x00100000
}

SECTIONS
{
    .text : {
        KEEP(*(.text.boot))
        *(.text*)
    } > DDR

    .rodata : { *(.rodata*) } > DDR
    .data   : { *(.data*)   } > DDR

    .bss (NOLOAD) : {
        . = ALIGN(4);
        __bss_start = .;
        *(.bss*) *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > DDR

    /* 16 KB of stack */
    .stack (NOLOAD) : {
        . = ALIGN(8);
        . += 0x4000;
        __stack_top = .;
    } > DDR

    /* Test result, read by XSDB: mrd 0x0011F000 4 */
    .ps_result 0x0011F000 (NOLOAD) : { KEEP(*(.ps_result)) } > DDR
}
