from abc import ABC
from addr_range import Addr_Ranges

class Node(ABC):
	def __init__(self, base_name: str, asgn_addr_ranges: Addr_Ranges, clock_domain: str, clock_frequency: int):
		self.BASE_NAME = base_name
		self.asgn_addr_ranges = asgn_addr_ranges
		self.CLOCK_DOMAIN: str = clock_domain
		self.CLOCK_FREQUENCY: int = clock_frequency

	def __getattr__(self, name):
		return getattr(self.asgn_addr_ranges, name)
