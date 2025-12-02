# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the Leaf class of the "Composite" design pattern
# this implements all the functions of the "Component" (Bus) class interface.
# This class lets all future "Leaf" bus types (the ones that can only have Peripherals
# attached to them) to just inherit from this class in order to be compatible
# with the Bus hierarchy modeled with the "Composite" design pattern.

from general.node import Node
from general.addr_range import Addr_Ranges
from peripherals.peripheral import Peripheral
from .bus import Bus
from typing import cast

class LeafBus(Bus):
	def __init__(self, base_name: str, data_dict: dict, asgn_addr_ranges: Addr_Ranges, axi_addr_width: int, 
					axi_data_width: int, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, data_dict, asgn_addr_ranges, axi_addr_width, 
						axi_data_width, clock_domain, clock_frequency)


	#Leaf busses just creates Peripherals based on all the "RANGES" attributes
	def _generate_children(self):
		self.children_peripherals = self._generate_peripherals(self.CHILDREN_NUM_RANGES, self._RANGE_NAMES, 
														 self._RANGE_BASE_ADDR, self._RANGE_ADDR_WIDTH, 
														 [self.CLOCK_DOMAIN]*len(self._RANGE_NAMES))

	#COMPONENT INTERFACE - LEAF IMPLEMENTATION
	#Base cases of the recursion

	#Leaf busses just need to sanitize the address ranges of peripherals
	def sanitize_addr_ranges(self):
		nodes: list[Node] = cast(list[Node], self.children_peripherals)
		super()._sanitize_addr_ranges(nodes)
	
	#Leaf busses just need to control that children peripherals are legal
	def check_legals(self):
		self._check_legal_peripherals()

	#Leaf busses just need to modify the reachability params of children peripherals
	def add_reachability(self):
		super()._add_peripherals_reachability()

	#Leaf bus don't support clock_domains object so just return
	def check_clock_domains(self):
		return
	
	#Leaf bus don't support childre_busses so just return
	def get_busses(self) -> list["Bus"] | None:
		return None

	#Leaf bus just need to return their peripherals
	def get_peripherals(self) -> list["Peripheral"]:
		return self.children_peripherals

