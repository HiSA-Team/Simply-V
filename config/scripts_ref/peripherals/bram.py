from addr_range import Addr_Range
from peripherals.peripheral import Peripheral

class Bram(Peripheral):
	def __init__(self, range_name: str, addr_ranges_list: list[Addr_Range], clock_domain: str, clock_frequency: int):

		super().__init__(range_name, addr_ranges_list, clock_domain, clock_frequency)
		self.IS_A_MEMORY = True

