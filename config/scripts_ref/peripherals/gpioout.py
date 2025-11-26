from peripherals.peripheral import Peripheral
from addr_range import Addr_Ranges

class GPIO_out(Peripheral):
	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
