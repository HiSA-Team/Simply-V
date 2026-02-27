SECTIONS {

    .vector_table _vector_table_start :
    {
        KEEP(*(.vector_table))
    }> BRAM

    .text :
    {
        . = ALIGN(32);
        _text_start = .;
        *(.text.handlers)
        *(.text.start)
        *(.text)
        *(.text*)
        . = ALIGN(32);
        _text_end = .;
    }> BRAM

   .bss : ALIGN(0x20)
   {
    __bss_start = .;
    *(.bss*);
    __bss_end = .;
   }> BRAM_0

   .data : ALIGN(0x20)
   {
    __data_start = .;
    *(.data*);
    __data_end = .;
   }> BRAM_0
}

/* --------------------------------------------------------------------------
   Link-time sanity checks
   -------------------------------------------------------------------------- */
ASSERT(__stack_bottom >= ORIGIN(BRAM_0),
       "Stack overflows below start of BRAM_0 -  reduce stack or data size")

ASSERT(_text_end <= __bram_end,
       ".text section exceeds BRAM_0 size")

ASSERT(__data_end <= __bram_end,
       ".data section exceeds BRAM_0 size")

ASSERT(__stack_bottom >= ORIGIN(BRAM_0),
       "Stack overflows below start of BRAM_0 - reduce stack or data size");

ASSERT(__bss_end <= __bram_end,
       ".bss section exceeds BRAM_0 size");

ASSERT(__data_end <= __bram_end,
       ".data section exceeds BRAM_0 size");

ASSERT(__stack_bottom >= __data_end,
       "Stack overlaps .data - reduce stack or data size");

ASSERT(__stack_bottom >= __bss_end,
       "Stack overlaps .bss - reduce stack or bss size");

ASSERT(MAX(__bss_end, __data_end) <= __stack_bottom,
       "Sections exceed available BRAM_0 space");

ASSERT(_stack_start == ALIGN(_stack_start, 16),
       "Stack top is not 16-byte aligned (RISC-V ABI requirement)");
