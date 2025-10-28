from node import Node

class Peripheral(Node):
	def __init__(self, name: str, asgn_addr_ranges: int, asgn_range_base_addr: list, \
			asgn_range_addr_width: list, clock_domain: str):

		self.IS_A_MEMORY: bool

		super().__init__(name, asgn_addr_ranges, asgn_range_base_addr, asgn_range_addr_width, clock_domain)

		if any(sub in self.NAME for sub in ["BRAM", "DDR", "HBM"]):
			self.IS_A_MEMORY = True
		else:
			self.IS_A_MEMORY = False


		
