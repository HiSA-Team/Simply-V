# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This file defines the plic peripheral

from general.addr_range import Addr_Ranges
from .peripheral import Peripheral


class PLIC(Peripheral):
	# Given the MMIO registers layout this peripheral needs 64 MBytes in the address space
	# refer to: https://docs.riscv.org/reference/hardware/plic/_attachments/riscv-plic.pdf
	# for the registers space
	min_addr_space = 67108864 # 64 MBs

	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
		self.HAL_DRIVER = True
