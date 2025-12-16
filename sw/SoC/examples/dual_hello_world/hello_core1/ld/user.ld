/*
    *** User-defined linker script ***

    If you want to extend the UninaSoC.ld script, place here your code.
    If you want to redefine your own linker script, remove the UninaSoC include.

*/

/* Override default base offset */
_default_base_offset = 0x8000;
_vector_table_start = _default_base_offset + 0x0000000000000000;
_vector_table_end   = _default_base_offset + 0x0000000000000080;

/* Inlcude common linker script */
INCLUDE ../../../common/UninaSoC.ld
