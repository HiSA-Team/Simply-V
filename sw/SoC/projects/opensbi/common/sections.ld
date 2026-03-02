/*
 * This linkerscript provides basic layout for the a S-mode payload.
 *
 * Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
*/

ENTRY(_start)

SECTIONS
{
    .text __payload_start : {
        KEEP(*(.text._start))
        *(.text*)
    } > DDR4CH1

    .rodata : ALIGN(8) {
        *(.rodata*)
    } > DDR4CH1

    .data : {
        *(.data*)
    } > DDR4CH1

    .bss (NOLOAD) : ALIGN(8) {
        *(.bss*)
        *(COMMON)
    } > DDR4CH1
}
