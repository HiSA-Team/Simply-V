from abc import ABC

class Node(ABC):
	def __init__(self, asgn_addr_ranges: int, asgn_range_base_addr: list, asgn_range_addr_width: list, clock: int):
		self.ASGN_ADDR_RANGES : int = asgn_addr_ranges 
		self.ASGN_RANGE_BASE_ADDR : list[int] = asgn_range_base_addr 
		self.ASGN_RANGE_ADDR_WIDTH : list[int] = asgn_range_addr_width 
		self.CLOCK: int = clock
		

