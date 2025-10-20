/*
    *** User-defined linker script ***
    Extends UninaSoC.ld by defining DDR start/end symbols
*/

INCLUDE ../../common/UninaSoC.ld

/* Define DDR start/end symbols globally */
PROVIDE(_DDR4CH1_start = ORIGIN(DDR));
PROVIDE(_DDR4CH1_end   = ORIGIN(DDR) + LENGTH(DDR));