from abc import ABC
import re

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
		# list of busses that can reach this node
		self.REACHABLE_FROM : list[str] = []
		
	def compute_range_end_addr(self, base_addr: int, addr_width: int) -> int:
		return base_addr + ~(~1 << (addr_width-1)) + 1

	def compute_range_end_addresses(self, base_addresses: list[int], addr_widths: list[int]) -> list[int]: 
		end_addresses = []
		for i in range(len(base_addresses)):
			end_addresses.append(self.compute_range_end_addr(base_addresses[i], addr_widths[i]))
		return end_addresses

	def add_to_reachable(self, bus_name: str):
		# in case of duplicates
		if(bus_name in self.REACHABLE_FROM):
			return

		self.REACHABLE_FROM.append(bus_name)
	
	def add_list_to_reachable(self, list_of_names: list[str]):
		for bus_name in list_of_names:
			# in case of duplicates
			if(bus_name in self.REACHABLE_FROM):
				continue
			self.REACHABLE_FROM.append(bus_name)
	
	#If the ranges aren't contiguous
	#get_end_addr() - get_base_addr() != total covered range of addresses
	#so in general don't assume this


	#GENERALIZING ON NUMBER OF ADDR_RANGES
	def get_base_addr(self):
		return min(self.ASGN_RANGE_BASE_ADDR)

	#GENERALIZING ON NUMBER OF ADDR_RANGES
	#this is the last address NOT addressable
	def get_end_addr(self):
		return max(self.ASGN_RANGE_END_ADDR)

	#Check if the address space of this node contains the address space passed
	def contains(self, base_addr: int, end_addr: int) -> bool:
		node_base_addresses = self.ASGN_RANGE_BASE_ADDR
		node_end_addresses = self.ASGN_RANGE_END_ADDR
		#for each node connected to the node check if it's included in at least
		#one node address range
		included = False

		for node_base, node_end in zip(node_base_addresses, node_end_addresses):
			if ((node_base <= base_addr) and (node_end >= end_addr)):
				included = True
				break

		return included

	#Check if the address space of this node is contained the address space passed
	def is_contained(self, base_addr: int, end_addr: int) -> bool:
		if ((base_addr <= self.get_base_addr()) and (self.get_end_addr() <= end_addr)):
			return True
		return False
