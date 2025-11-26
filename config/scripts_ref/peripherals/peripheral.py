from addr_range import Addr_Ranges
from node import Node

class Peripheral(Node):
	def __init__(self, base_name: str, asgn_addr_ranges: Addr_Ranges, clock_domain: str, clock_frequency: int):

		self.IS_A_MEMORY: bool = False
		super().__init__(base_name, asgn_addr_ranges, clock_domain, clock_frequency)

		# need to check for DDR clock
