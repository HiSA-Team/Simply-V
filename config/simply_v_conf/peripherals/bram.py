import os
from pathlib import Path
import re
from general.addr_range import Addr_Ranges
from .peripheral import Peripheral

class Bram(Peripheral):
	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
		self.IS_A_MEMORY = True

	def config_ip(self, root_path: str, **kwargs) -> None:
		# use FULLNAME to find IP
		bram_path = os.path.join(root_path, "xlnx_" + self.FULL_NAME.lower(), "config.tcl")
		bram_path = Path(bram_path)

		length = 0
		# generalize to many ranges to compute the bram space address length
		dimensions = self.asgn_addr_ranges.get_range_dimensions(explicit=True)
		for values in dimensions.values():
			length += values[2]
		# divide for XLEN_bytes
		bram_depth = int(length / kwargs["xlen_bytes"])
		content = bram_path.read_text()
		pattern = r"(set\s+bram_depth)\s*\{[^}]+\}"
		replacement = rf"\1 {{{bram_depth}}}"

		updated = re.sub(pattern, replacement, content)
		bram_path.write_text(updated)
