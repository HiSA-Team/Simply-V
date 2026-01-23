# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This file defines the DDR4 peripheral

from general.addr_range import Addr_Ranges
from .peripheral import Peripheral
import re
import os
from pathlib import Path

# DDR4 has its own clock domain, so it doesn't accept values when initialized
# but just statically initialize its clock domain based on the channel
# the only exception is the MBUS that will try to configure the CLOCK_DOMAIN
# based on its .csv values, so a check on correctness need to be done
class DDR4(Peripheral):
	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, \
					   channel: int, father_bus_name: str):

		static_domain = f"DDR4CH{channel}_300"
		static_frequency = 300

		super().__init__(base_name, addr_ranges_list, static_domain, static_frequency)
		self.IS_A_MEMORY = True
		self.IS_CLOCK_GENERATOR = True
		self.CHANNEL = channel

		# MBUS will propagate the clock domain from its .csv file (RANGE_CLOCK_DOMAINS)
		# so we need to enforce the correct value
		if(father_bus_name == "MBUS") and (clock_domain != static_domain):
			raise ValueError(f"DDR4CH_{channel} was configured by MBUS with CLOCK_DOMAIN: "
							 f"{clock_domain}, the only acceptable value is {static_domain}")


	def config_ip(self, root_path: str, **kwargs) -> None:
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
