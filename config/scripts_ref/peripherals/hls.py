from peripherals.peripheral import Peripheral
from addr_range import Addr_Range

class HLS(Peripheral):
	def __init__(self, addr_ranges_list: list[Addr_Range]):

		super().__init__(addr_ranges_list)

