from abc import ABC

class Node(ABC):
	def __init__(self, addr_ranges: int, base_addr: int, range_addr_width: int, clock: int):
		self.ADDR_RANGES : int = addr_ranges
		self.BASE_ADDR : int = base_addr
		self.RANGE_ADDR_WIDTH : int = range_addr_width
		self.CLOCK: int = clock
		

