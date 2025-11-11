from peripherals.peripheral import Peripheral

class HLS(Peripheral):
	def __init__(self, name: str, base_name: str, asgn_addr_ranges: int, asgn_range_base_addr: list, \
			asgn_range_addr_width: list, clock_domain: str):

		super().__init__(name, base_name, asgn_addr_ranges, asgn_range_base_addr, asgn_range_addr_width, clock_domain)

