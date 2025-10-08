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

		self.ASGN_RANGE_END_ADDR = self.compute_range_end_addresses(self.ASGN_RANGE_BASE_ADDR, self.ASGN_RANGE_ADDR_WIDTH)
		
	def compute_range_end_addr(self, base_addr: int, addr_width: int) -> int:
		return base_addr + ~(~1 << (addr_width-1)) + 1

	def compute_range_end_addresses(self, base_addresses: list[int], addr_widths: list[int]) -> list[int]: 
		end_addresses = []
		for i in range(len(base_addresses)):
			end_addresses.append(self.compute_range_end_addr(base_addresses[i], addr_widths[i]))
		return end_addresses
