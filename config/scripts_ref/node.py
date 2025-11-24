from abc import ABC
import re
from addr_range import Addr_Range

class Node(ABC):
	def __init__(self, range_name: str, asgn_addr_ranges: list[Addr_Range], clock_domain: str, clock_frequency: int):
		self.NAME = range_name
		self.BASE_NAME = asgn_addr_ranges[0].BASE_NAME
		self.asgn_addr_ranges = asgn_addr_ranges
		self.CLOCK_DOMAIN: str = clock_domain
		self.CLOCK_FREQUENCY: int = clock_frequency
	

	#Check if one of the address ranges of this Bus contains the address range passed
	def __contains__(self, node: "Node") -> bool:
		return any(
			addr_range1 in addr_range2
			for addr_range1 in node.asgn_addr_ranges
			for addr_range2 in self.asgn_addr_ranges
		)

	def overlaps(self, node: "Node") -> bool:
		for self_range in self.asgn_addr_ranges:
			if (any(self_range.overlaps(node_range) for node_range in node.asgn_addr_ranges)):
				return True
		return False

	def split_addr_ranges(self):
		for addr_range in self.asgn_addr_ranges:
			addr_range.split()

	def get_base_addr(self):
		return min(addr_range.RANGE_BASE_ADDR for addr_range in self.asgn_addr_ranges)

	def get_end_addr(self):
		return max(addr_range.RANGE_END_ADDR for addr_range in self.asgn_addr_ranges)

	def add_to_reachable(self, name: str):
		for addr_range in self.asgn_addr_ranges:
			addr_range.add_to_reachable(name)

	def add_list_to_reachable(self, list_of_names: list[str]):
		for addr_range in self.asgn_addr_ranges:
			addr_range.add_list_to_reachable(list_of_names)

	def get_reachable_from(self) -> list[str]:
		list_of_names = []
		for addr_range in self.asgn_addr_ranges:
			list_of_names.extend(addr_range.REACHABLE_FROM)
		return list_of_names

	def get_ranges_names(self) -> list[str]:
		list_of_names = []
		for addr_range in self.asgn_addr_ranges:
			list_of_names.append(addr_range.RANGE_NAME)
		return list_of_names
