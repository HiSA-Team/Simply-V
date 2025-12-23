/*
    *** User-defined linker script ***

    If you want to extend the UninaSoC.ld script, place here your code.
    If you want to redefine your own linker script, remove the UninaSoC include.

*/

/* Override default _stack_start */
_stack_start = 0x0000000000007ff8;

/* Inlcude common linker script */
INCLUDE ../../../common/UninaSoC.ld

