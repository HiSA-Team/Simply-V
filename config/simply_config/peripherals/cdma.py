# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This file defines the CDMA peripheral

from general.addr_range import Addr_Ranges
from .peripheral import Peripheral

class CDMA(Peripheral):
	# Given the MMIO registers layout this peripheral needs 44 bytes in the address space
	# refer to: https://docs.riscv.org/reference/hardware/plic/_attachments/riscv-plic.pdf
	# for the registers space
	min_addr_space = 44

	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
		self.HAL_DRIVER = True
