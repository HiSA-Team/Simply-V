/*
 * Auto-generated with create_linker_script.py
 *
 * This linkerscript provides basic layout for the a S-mode payload.
 *
 * Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
*/

ENTRY(_start)

MEMORY
{
	DDR4CH1 (xrw): ORIGIN = 0x0000000001200000, LENGTH = 0xe00000
}

__stack_top = ORIGIN(DDR4CH1) + LENGTH(DDR4CH1);

SECTIONS
{
    . = ORIGIN(DDR4CH1);

    .text : {
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
