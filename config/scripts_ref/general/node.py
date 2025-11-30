from abc import ABC
from .addr_range import Addr_Ranges

class Node(ABC):
	def __init__(self, base_name: str, asgn_addr_ranges: Addr_Ranges, clock_domain: str, clock_frequency: int):
		self.asgn_addr_ranges = asgn_addr_ranges
		self.BASE_NAME = base_name
		self.FULL_NAME = asgn_addr_ranges.FULL_NAME
		self.CLOCK_DOMAIN: str = clock_domain
		self.CLOCK_FREQUENCY: int = clock_frequency

	def __str__(self):
		return (f"Node(BASE_NAME='{self.BASE_NAME}', FULL_NAME='{self.FULL_NAME}', "
                f"CLOCK_DOMAIN='{self.CLOCK_DOMAIN}', CLOCK_FREQUENCY={self.CLOCK_FREQUENCY}, "
                f"asgn_addr_ranges={self.asgn_addr_ranges})")

	def get_base_addr(self):
		return self.asgn_addr_ranges.get_base_addr()

	def get_end_addr(self):
		return self.asgn_addr_ranges.get_end_addr()

	def split_addr_ranges(self):
		return self.asgn_addr_ranges.split_addr_ranges()
