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
    } > OPENSBI_MEMORY

    .rodata : ALIGN(8) {
        *(.rodata*)
    } > OPENSBI_MEMORY

    .data : {
        *(.data*)
    } > OPENSBI_MEMORY

    .bss (NOLOAD) : ALIGN(8) {
        *(.bss*)
        *(COMMON)
    } > OPENSBI_MEMORY
}
