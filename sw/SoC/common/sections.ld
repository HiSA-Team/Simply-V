/* Auto-generated with create_linkerscript_fragments.py */

SECTIONS
{
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
}