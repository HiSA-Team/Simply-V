# Author: Vincenzo Masito <vincenzo.maisto2@unina.it>
# Description: This file defines the CLINT peripheral

from general.addr_range import Addr_Ranges
from .peripheral import Peripheral


class CLINT(Peripheral):
	# Given the MMIO registers layout:
	# - msip     : 0x0000
	# - mtimecmp : 0x4000 - 0x4008 (64-bit)
	# - mtime    : 0xBFF8 - 0xC000 (64-bit)
	# Reference: https://github.com/pulp-platform/clint/tree/v0.2.0
	min_addr_space = 0xC000

	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
		self.HAL_DRIVER = True
