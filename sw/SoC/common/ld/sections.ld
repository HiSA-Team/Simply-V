/* Auto-generated with ld_template.py */
SECTIONS
{
	.vector_table _vector_table_start :
	{
		KEEP(*(.vector_table))
	}> BRAM_0

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
	}> BRAM_0
}
