/*
 * This is the linkerscript for FreeRTOS application. This includes the UninaSoC.ld and defines 
 * the BSS and DATA section where FreeRTOS Heap and static variables will be allocated. Also it defines
 * the symbols for the stack and performs some checks.
 *
 * Author: Giusppe Capasso <giuseppe.capasso17@studenti.unina.it>
 */

INCLUDE ../../../../common/UninaSoC.ld

/* 

vector_table_start,defined in uninasoc.ld,is the address of reset handler
trap_vector_start is the base address for the interrupt handlers

*/

/* let's assume this memory block is defined in UninaSoC.ld */
__bram_end        = ORIGIN(BRAM) + LENGTH(BRAM);
__stack_size      = 0x1000; /* 4k */
__stack_bottom    = _stack_start - __stack_size;

/* https://www.freertos.org/Using-FreeRTOS-on-RISC-V#interrupt-system-stack-setup */
__freertos_irq_stack_top = _stack_start;

SECTIONS {

   .bss : ALIGN(0x20)
   {
    __bss_start = .;
    *(.bss*);
    __bss_end = .;
   }> BRAM

   .data : ALIGN(0x20)
   {
    __data_start = .;
    *(.data*);
    __data_end = .;
   }> BRAM
}

/* --------------------------------------------------------------------------
   Link-time sanity checks
   -------------------------------------------------------------------------- */
ASSERT(__stack_bottom >= ORIGIN(BRAM),
       "Stack overflows below start of BRAM -  reduce stack or data size")

ASSERT(_text_end <= __bram_end,
       ".text section exceeds BRAM size")

ASSERT(__data_end <= __bram_end,
       ".data section exceeds BRAM size")

ASSERT(__stack_bottom >= ORIGIN(BRAM),
       "Stack overflows below start of BRAM - reduce stack or data size");

ASSERT(__bss_end <= __bram_end,
       ".bss section exceeds BRAM size");

ASSERT(__data_end <= __bram_end,
       ".data section exceeds BRAM size");

ASSERT(__stack_bottom >= __data_end,
       "Stack overlaps .data - reduce stack or data size");

ASSERT(__stack_bottom >= __bss_end,
       "Stack overlaps .bss - reduce stack or bss size");

ASSERT(MAX(__bss_end, __data_end) <= __stack_bottom,
       "Sections exceed available BRAM space");

ASSERT(_stack_start == ALIGN(_stack_start, 16),
       "Stack top is not 16-byte aligned (RISC-V ABI requirement)");
