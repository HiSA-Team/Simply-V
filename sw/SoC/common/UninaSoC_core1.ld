/* Memory blocks */
MEMORY
{
    /* Frame per core1: 0x8000 - 0xFFFF (32 KB) */
    BRAM (xrw) : ORIGIN = 0x0000000000008000,  LENGTH = 0x8000
}

/* Peripherals symbols: identici a core0 */
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
/* Frame core1 parte da 0x8000 */
_vector_table_start = 0x0000000000008000;
_vector_table_end   = 0x0000000000008080;
/* Top dello stack = fine dell’intera BRAM (0x10000) - 8,
   che appartiene comunque al frame core1 */
_stack_start        = 0x000000000000fff8;


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

