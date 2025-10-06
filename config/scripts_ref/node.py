from abc import ABC

class Node(ABC):
	def __init__(self, name: str, asgn_addr_ranges: int, asgn_range_base_addr: list, asgn_range_addr_width:\
			list, clock: int,):

		self.NAME: str = name
		self.ASGN_ADDR_RANGES : int = asgn_addr_ranges 
		self.ASGN_RANGE_BASE_ADDR : list[int] = asgn_range_base_addr 
		self.ASGN_RANGE_ADDR_WIDTH : list[int] = asgn_range_addr_width 
		self.ASGN_RANGE_END_ADDR : list[int] = []	# computed from ASGN_RANGE_BASE_ADDR and ASGN_RANGE_ADDR_WIDTH
		self.CLOCK: int = clock
		self.children : list[Node] = []
		

		for i in range(self.ASGN_ADDR_RANGES):
			# RANGE_ADDR_WIDTH contained in the "Node" object of this bus
			self.ASGN_RANGE_END_ADDR.append(self.ASGN_RANGE_BASE_ADDR[i] + ~(~1 << (self.ASGN_RANGE_ADDR_WIDTH[i]-1)))

