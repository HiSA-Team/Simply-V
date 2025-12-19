from general.addr_range import Addr_Ranges
from .peripheral import Peripheral
import re
import os
from pathlib import Path

class DDR4(Peripheral):
	LEGAL_CLOCK = 300
	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int,
					channel: int):

		if (clock_frequency != self.LEGAL_CLOCK):
			raise ValueError(f"DDR4 channel {channel} has a wrong clock frequency (must be 300)")

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
		self.IS_A_MEMORY = True
		self.CHANNEL = channel
		self.IS_CLOCK_GENERATOR = True

	def config_ip(self, root_path: str) -> None:
		# use channel number to find corresponding cache
		cache_name = f"xlnx_system_cache_ddr4ch{self.CHANNEL}"
		cache_path = os.path.join(root_path, cache_name, "config.tcl")
		cache_path = Path(cache_path)

		# assume that isn't mandatory for a ddr to have a cache to configure,
		# so just return if the ip file isn't found
		try:
			text = cache_path.read_text()
		except:
			return

		base_hex = f"0x{self.get_base_addr():x}"
		# minus 1 because get_end_addr returns the first address OUTSIDE the range
		high_hex = f"0x{self.get_end_addr()-1:x}"

		# configure base and end addresses
		text = re.sub(
			r"(set CACHE_BASEADDR)\s*\{[^}]+\}",
			rf"\1 {{{base_hex}}}",
			text
		)

		text = re.sub(
			r"(set CACHE_HIGHADDR)\s*\{[^}]+\}",
			rf"\1 {{{high_hex}}}",
			text
		)

		cache_path.write_text(text)
