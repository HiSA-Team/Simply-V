# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This file defines the hbm peripheral

from general.addr_range import Addr_Ranges
from .peripheral import Peripheral


class HBM(Peripheral):
	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
		self.IS_A_MEMORY = True
