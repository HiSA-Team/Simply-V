# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This file defines the gpio out peripheral


from general.addr_range import Addr_Ranges
from .peripheral import Peripheral

class GPIO_out(Peripheral):
	# Given the MMIO registers layout this peripheral needs 300 bytes in the address space
	# refer to: https://docs.amd.com/v/u/en-US/pg144-axi-gpio
	# for the registers space
	min_addr_space = 300 

	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
		self.HAL_DRIVER = True
