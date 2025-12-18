# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
# Description: Class that can generate HAL header using all the peripherals (devices + memories) 
#				configured in the CSVs

import textwrap
import os
from peripherals.peripheral import Peripheral

class HALheader_Template:
	# using "dedent" to ignore leading spaces
	str_template: str = textwrap.dedent("""\
	// This file is auto-generated with {this_file}

	#ifndef {include_guard}
	#define {include_guard}

	#include <stdint.h>

	{peripheral_block_str}

	{device_block_str}

	#endif // {include_guard}
	""")

	# Produces a C preprocessor define with:
	# "#define _peripheral_DEVICE_NAME_start 0x{base}"
	# "#define _peripheral_DEVICE_NAME_end   0x{end}"
	def _init_peripheral_block_str(self, peripherals: list[Peripheral]) -> str:
		lines = []
		dimensions_dict = {}
		for p in peripherals:
			# retrieve addr ranges dimensions in order to generalize on the number of address ranges
			dimensions_dict |= p.asgn_addr_ranges.get_range_dimensions(explicit=False)

		for name, dimensions in dimensions_dict.items():
			name = name
			base = dimensions[0]
			end = dimensions[1]
			lines.append(f"#define _peripheral_{name}_start  0x{base:016x}")
			lines.append(f"#define _peripheral_{name}_end    0x{end:016x}")
		return "\n".join(lines)

	# Produces a C preprocessor define with:
	# "#define DEVICE_NAME_IS_ENABLED 1"
	def _init_device_block_str(self, devices: list[Peripheral]) -> str:
		lines = []
		names = set()
		for d in devices:
			# check if device has an HAL driver to
			# conditionally enable
			if d.HAL_DRIVER:
				names.add(d.BASE_NAME)

		for name in names:
			lines.append(f"#define {name}_IS_ENABLED 1")

		return "\n".join(lines)

	def __init__(self, peripherals: list[Peripheral], devices: list[Peripheral]):
		self.peripheral_block_str = self._init_peripheral_block_str(peripherals)
		self.device_block_str = self._init_device_block_str(devices)

	def write_to_file(self, file_name: str) -> None:
		# Extract base name and make it a valid macro name for the include guard
		base_filename = os.path.basename(file_name).replace(".", "_").upper()
		include_guard = f"__{base_filename}__"
		# The hal_template_str is a string which can be formatted (same as f-string). Provide {variable}
		# as strings. This is why we call render_* functions
		rendered = self.str_template.format(
											this_file = os.path.basename(__file__),
											peripheral_block_str = self.peripheral_block_str,
											include_guard = include_guard,
											device_block_str = self.device_block_str,
											)

		# === Output to file ===
		with open(file_name, "w") as f:
			f.write(rendered)
