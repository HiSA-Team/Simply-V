/*
    *** User-defined linker script ***

    If you want to extend the simplyv.ld script, place here your code.
    If you want to redefine your own linker script, remove the simplyv include.

*/

/* Override default _stack_start */
_stack_start = 0x0000000000007ff8;
