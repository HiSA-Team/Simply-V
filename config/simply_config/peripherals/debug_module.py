# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This file defines the debug module (DM) peripheral


from general.addr_range import Addr_Ranges
from .peripheral import Peripheral


class Debug_Module(Peripheral):
	# Given the MMIO registers layout this peripheral needs 16384 bytes in the address space
	# refer to: https://github.com/pulp-platform/riscv-dbg/blob/v0.8.1/doc/debug-system.md#debug-memory
	# for the registers space
	min_addr_space = 16384

	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
