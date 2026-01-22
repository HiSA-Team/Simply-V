# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This file defines the timer peripheral

from general.addr_range import Addr_Ranges
from .peripheral import Peripheral


class Timer(Peripheral):
	# Given the MMIO registers layout this peripheral needs 32 bytes in the address space
	# refer to: https://docs.amd.com/viewer/book-attachment/7aOjdvedJEcrg0QugvEIRw/VvRPtTvuW7m8g783LjGXZg-7aOjdvedJEcrg0QugvEIRw
	# for the registers space
	min_addr_space = 32

	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
		self.HAL_DRIVER = True
