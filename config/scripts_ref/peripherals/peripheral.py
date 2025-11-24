from addr_range import Addr_Range
from node import Node

class Peripheral(Node):
	def __init__(self, range_name: str, asgn_addr_ranges: list[Addr_Range], clock_domain: str, clock_frequency: int):

		self.IS_A_MEMORY: bool = False
		super().__init__(range_name, asgn_addr_ranges, clock_domain, clock_frequency)

		# need to check for DDR clock
