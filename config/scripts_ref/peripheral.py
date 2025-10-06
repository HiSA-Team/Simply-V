from node import Node

class Peripheral(Node):
	def __init__(self, name: str, asgn_addr_ranges: int, asgn_range_base_addr: list, \
			asgn_range_addr_width: list, clock: int):

		self.LEGAL_CLOCK_DOMAIN: list[int] = []

		super().__init__(name, asgn_addr_ranges, asgn_range_base_addr, asgn_range_addr_width, clock)
		
