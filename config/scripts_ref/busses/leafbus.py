# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the Leaf class of the "Composite" design pattern
# this implements all the functions of the "Component" (Bus) class interface.
# This class lets all future "Leaf" bus types (the ones that can only have Peripherals
# attached to them) to just inherit from this class in order to be compatible with
# with the Bus hierarchy modeled with the "Composite" design pattern.

from node import Node
from addr_range import Addr_Ranges
from peripherals.peripheral import Peripheral
from busses.bus import Bus
from typing import cast

class LeafBus(Bus):
	def __init__(self, base_name: str, data_dict: dict, asgn_addr_ranges: Addr_Ranges, axi_addr_width: int, 
					axi_data_width: int, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, data_dict, asgn_addr_ranges, axi_addr_width, 
						axi_data_width, clock_domain, clock_frequency)


	def _generate_children(self):
		#Leaf busses just creates Peripherals based on all the "RANGES" attributes
		self.children_peripherals = self._generate_peripherals(self.ADDR_RANGES, self._RANGE_NAMES, 
														 self._RANGE_BASE_ADDR, self._RANGE_ADDR_WIDTH, 
														 self.CLOCK_DOMAIN)

	#COMPONENT INTERFACE - LEAF IMPLEMENTATION
	#Base cases of the recursion

	def sanitize_addr_ranges(self):
		#Leaf busses just need to sanitize the address ranges of peripherals
		nodes: list[Node] = cast(list[Node], self.children_peripherals)
		super()._sanitize_addr_ranges(nodes)
	
	def check_legals(self):
		#Leaf busses just need to control that children peripherals are legal
		self._check_legal_peripherals()

	def add_reachability(self):
		#Leaf busses just need to modify the reachability params of children peripherals
		super()._add_peripherals_reachability()

	def check_clock_domains(self):
		#Leaf bus don't support clock_domains object so just return
		return
	
	def get_busses(self) -> list["Bus"] | None:
		#Leaf bus don't support childre_busses so just return
		return None

	def get_peripherals(self) -> list["Peripheral"]:
		#Leaf bus just need to return their peripherals
		return self.children_peripherals
