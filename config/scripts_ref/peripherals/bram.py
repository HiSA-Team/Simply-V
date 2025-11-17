from addr_range import Addr_Range
from peripherals.peripheral import Peripheral

class Bram(Peripheral):
	def __init__(self, addr_ranges_list: list[Addr_Range]):

		super().__init__(addr_ranges_list)
		self.IS_A_MEMORY = True

