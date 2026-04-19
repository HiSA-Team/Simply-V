/* Auto-generated with create_linkerscript_fragments.py */

/* Memory blocks */
MEMORY
{
	BRAM (xrw): ORIGIN = 0x0000000000000000, LENGTH = 0x10000
	DDR4CH1 (xrw): ORIGIN = 0x0000000001000000, LENGTH = 0x1000000
	DDR4CH0 (xrw): ORIGIN = 0x0000000000090000, LENGTH = 0x10000
}