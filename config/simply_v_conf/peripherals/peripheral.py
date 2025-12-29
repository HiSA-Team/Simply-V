# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This file defines the "Peripheral" base class, used from all the peripherals hierarchy

from general.addr_range import Addr_Ranges
from general.node import Node

class Peripheral(Node):
	def __init__(self, base_name: str, asgn_addr_ranges: Addr_Ranges, clock_domain: str, clock_frequency: int):

		self.IS_A_MEMORY: bool = False
		# Used by the configuration flow to enable conditional compilation
		# of C drivers in the HAL if the peripheral is included in the configuration
		self.HAL_DRIVER: bool = False
		super().__init__(base_name, asgn_addr_ranges, clock_domain, clock_frequency)

	
	def config_ip(self, root_path: str, **kwargs) -> None:
		return
