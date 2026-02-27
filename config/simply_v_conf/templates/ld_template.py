# Author: Stefano Toscano               <stefa.toscano@studenti.unina.it>
# Author: Vincenzo Maisto               <vincenzo.maisto2@unina.it>
# Author: Stefano Mercogliano           <stefano.mercogliano@unina.it>
# Author: Giuseppe Capasso              <giuseppe.capasso17@studenti.unina.it>
# Author: Salvatore Santoro				<sal.santoro@studenti.unina.it>
# Description:
#   Class that can generate a linker script file using all the peripherals specified in the CSVs.

import textwrap
import os
from .template import Template
from peripherals.peripheral import Peripheral

class Ld_Template(Template):
	# using "dedent" to ignore leading spaces
	memory_template_str : str = textwrap.dedent("""\
	/* Auto-generated with {this_file} */

	MEMORY
	{{
	{memory_block_str}
	}}
	""")

	variables_template_str : str = textwrap.dedent("""\
	/* Auto-generated with {this_file} */

	/* Global symbols */
	{globals_block_str}
	""")

	sections_template_str : str = textwrap.dedent("""\
	/* Auto-generated with {this_file} */
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
		lines.append(f"_vector_table_start = 0x{self.boot_memory_base:016x};")
		lines.append(f"_vector_table_end = 0x{self.boot_memory_base + (32*4):016x};")
		lines.append(f"_stack_start = 0x{self.stack_start:016x};")

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
		assert False, "Simply-V should already validated correctness of boot_memory"


	def __init__(self, memories: list[Peripheral], boot_memory_name: str):
		dimensions_dict: dict[str, tuple[int, int, int]] = {}
		self.boot_memory_str: str = boot_memory_name
		self.boot_memory_base: int
		self.stack_start: int

		for m in memories:
			# retrieve addr ranges dimensions in order to generalize on the number of address ranges
			dimensions_dict |= m.assigned_addr_ranges.get_range_dimensions(explicit=False)

		self._init_boot_values(dimensions_dict, boot_memory_name)

		self.memory_block_str = self._init_memory_block_str(dimensions_dict)
		self.globals_block_str = self._init_global_symbols_str()


	# Used by template.py in the write_to_file implementation
	# Mock implementation, that should neved be called
	def get_params(self) -> dict[str, str]:
		raise Exception("This function should never be called!")
		return {"", ""}
	# 	return {
	# 			"this_file": os.path.basename(__file__),
	# 			"memory_block_str": self.memory_block_str,
	# 			"globals_block_str": self.globals_block_str,
	# 			"boot_memory_str": self.boot_memory_str
	# 			}

	# Write Memory fragment
	def write_to_file_memory(self, file_name: str) -> None:
		# Formatted string
		formatted = self.memory_template_str.format(
			this_file = os.path.basename(__file__),
			memory_block_str = self.memory_block_str,
		)
		# Write to file
		with open(file_name, "w", encoding="utf-8") as f:
			f.write(formatted)

	# Write Sections fragment
	def write_to_file_sections(self, file_name: str) -> None:
		# Formatted string
		formatted = self.sections_template_str.format(
			this_file = os.path.basename(__file__),
			boot_memory_str = self.boot_memory_str,
		)
		# Write to file
		with open(file_name, "w", encoding="utf-8") as f:
			f.write(formatted)

	# Write Variables fragment
	def write_to_file_variables(self, file_name: str) -> None:
		# Formatted string
		formatted = self.variables_template_str.format(
			this_file = os.path.basename(__file__),
			globals_block_str = self.globals_block_str,
		)
		# Write to file
		with open(file_name, "w", encoding="utf-8") as f:
			f.write(formatted)
