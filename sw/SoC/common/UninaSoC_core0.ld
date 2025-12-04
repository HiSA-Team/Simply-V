/* Memory blocks */
MEMORY
{
    /* Frame per core0: 0x0000 - 0x7FFF (32 KB) */
    BRAM (xrw) : ORIGIN = 0x0000000000000000,  LENGTH = 0x8000
}

/* Peripherals symbols */
_peripheral_DM_mem_start   = 0x0000000000010000;
_peripheral_DM_mem_end     = 0x0000000000020000;
_peripheral_PLIC_start     = 0x0000000004000000;
_peripheral_PLIC_end       = 0x0000000008000000;
_peripheral_UART_start     = 0x0000000000020000;
_peripheral_UART_end       = 0x0000000000020010;
_peripheral_GPIO_out_start = 0x0000000000020200;
_peripheral_GPIO_out_end   = 0x0000000000020400;
_peripheral_GPIO_in_start  = 0x0000000000020400;
_peripheral_GPIO_in_end    = 0x0000000000020600;
_peripheral_TIM0_start     = 0x0000000000020600;
_peripheral_TIM0_end       = 0x0000000000020620;
_peripheral_TIM1_start     = 0x0000000000020620;
_peripheral_TIM1_end       = 0x0000000000020640;

/* Global symbols */
/* Tutto il frame di core0 parte da 0x0000 */
_vector_table_start = 0x0000000000000000;
_vector_table_end   = 0x0000000000000080;
/* Top dello stack = fine frame core0 (0x8000) - 8 */
_stack_start        = 0x0000000000007ff8;


/* Sections */
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

