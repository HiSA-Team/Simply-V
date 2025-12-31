# Author: Stefano Toscano               <stefa.toscano@studenti.unina.it>
# Author: Vincenzo Maisto               <vincenzo.maisto2@unina.it>
# Author: Stefano Mercogliano           <stefano.mercogliano@unina.it>
# Author: Giuseppe Capasso              <giuseppe.capasso17@studenti.unina.it>
# Author: Salvatore Santoro				<sal.santoro@studenti.unina.it>
# Description:
#   Class that can generate a linker script file using all the peripherals specified in the CSVs.

import textwrap
import os
from peripherals.peripheral import Peripheral


# Note: The memory size specified in the config.csv file may differ from the
# physical memory allocated for the SoC (refer to hw/xilinx/ips/common/xlnx_blk_mem_gen/config.tcl).
# Currently, the configuration process does not ensure alignment between config.csv
# and xlnx_blk_mem_gen/config.tcl. As a result, we assume a maximum memory size of
# 32KB for now, based on the current setting in `config.tcl`.

class Ld_Template():
	# using "dedent" to ignore leading spaces
	str_template: str = textwrap.dedent("""\
	/* Auto-generated with {this_file} */

	MEMORY
	{{
	{memory_block_str}
	}}

	/* Global symbols */
	{globals_block_str}

	SECTIONS
	{{
		.vector_table _vector_table_start :
		{{
			KEEP(*(.vector_table))
		}}> {boot_memory_str}

		.text :
		{{
			. = ALIGN(32);
			_text_start = .;
			*(.text.handlers)
			*(.text.start)
			*(.text)
			*(.text*)
			. = ALIGN(32);
			_text_end = .;
		}}> {boot_memory_str}
	}}
	""")

	# The output of the should be a string in the linkerscript format. Eg:
	# BRAM (xrw): ORIGIN = 0x0, LENGHTa = 0x10000
	def _init_memory_block_str(self, memories: dict[str, tuple[int, int, int]]) -> str:
		lines = []
		
		for name, dimensions in memories.items():
			permissions = "xrw"
			base = dimensions[0]
			len = dimensions[2]
			lines.append(
				f"\t{name} ({permissions}): ORIGIN = 0x{base:016x}, LENGTH = 0x{len:0x}"
			)
		return "\n".join(lines)


	def _init_global_symbols_str(self):
		lines = []
		lines.append(f"PROVIDE(_vector_table_start = 0x{self.boot_memory_base:016x});")
		lines.append(f"PROVIDE(_vector_table_end = 0x{self.boot_memory_base + (32*4):016x});")
		lines.append(f"PROVIDE(_stack_start = 0x{self.stack_start:016x});")

		return "\n".join(lines)


	def _init_boot_values(self, memories: dict[str, tuple[int, int, int]], boot_memory_name: str) -> None:
		for name, dimensions in memories.items():
			# check the name of the memory to be equal to the boot one specified
			if(name == boot_memory_name):
				self.boot_memory_base = dimensions[0]
				# _stack_end can be user-defined for the application, as bss and rodata
				# _stack_end will be aligned to 64 bits, making it working for both 32 and 64 bits configurations
				# The stack is allocated at the end of first memory block and is 16 bytes aligned
				# ~(15) = 0x111....0000 so anding with it effectively lowers the first 4 bits,
				# making the value aligned to 16
				self.stack_start = (dimensions[1] - 1) & ~(15)
				return

		# boot memory not found
		raise ValueError(f"Unable to find a memory suited for booting (Selected boot memory is {boot_memory_name})")


	def __init__(self, memories: list[Peripheral], boot_memory_name: str):
		dimensions_dict: dict[str, tuple[int, int, int]] = {}
		self.boot_memory_str: str = boot_memory_name
		self.boot_memory_base: int
		self.stack_start: int

		for m in memories:
			# retrieve addr ranges dimensions in order to generalize on the number of address ranges
			dimensions_dict |= m.asgn_addr_ranges.get_range_dimensions(explicit=False)

		self._init_boot_values(dimensions_dict, boot_memory_name)

		self.memory_block_str = self._init_memory_block_str(dimensions_dict)
		self.globals_block_str = self._init_global_symbols_str()


	def write_to_file(self, file_name: str) -> None:
		formatted = self.str_template.format( 
											this_file = os.path.basename(__file__),
											memory_block_str = self.memory_block_str,
											globals_block_str = self.globals_block_str,
											boot_memory_str = self.boot_memory_str
											)
		with open(file_name, "w", encoding="utf-8") as f:
			f.write(formatted)
