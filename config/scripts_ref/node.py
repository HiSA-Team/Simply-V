from abc import ABC

class Node(ABC):
	def __init__(self, assigned_addr_ranges: int, base_addr: list, range_addr_width: list, clock: int):
		self.ASSIGNED_ADDR_RANGES : int =assigned_addr_ranges 
		self.RANGE_BASE_ADDR : list = base_addr
		self.RANGE_ADDR_WIDTH : list = range_addr_width 
		self.CLOCK: int = clock
		

