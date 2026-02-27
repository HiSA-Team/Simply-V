# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This file defines the "Peripheral" base class, used from all the peripherals hierarchy

from general.error import Unsupported_Value_Error
from general.addr_range import Addr_Ranges
from general.node import Node

class Peripheral(Node):
	# Value to check erroneous configuration of the ADDR_WIDTH for a peripheral.
	# Since devices using MMIO need to have a certain address range associated to them
	# to map their registers, not giving them sufficient memory will make some registers
	# unadressable (children classes will redefine this value accordingly in order to enforce
	#               the right check in the Peripheral constructor)
	# measured in bytes
	min_addr_space: int = 0

	def __init__(self, base_name: str, assigned_addr_ranges: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, assigned_addr_ranges, clock_domain, clock_frequency)
		self.IS_A_MEMORY: bool = False
		# Used by the configuration flow to enable conditional compilation
		# of C drivers in the HAL if the peripheral is included in the configuration
		self.HAL_DRIVER: bool = False

		# Get address dimensions associated to this Node
		dimensions = self.assigned_addr_ranges.get_range_dimensions(explicit=False)
		ranges_length = 0

		for value in dimensions.values():
			# Second element is the range length
			ranges_length += value[2]

		if (ranges_length < self.min_addr_space):
			details = "Minimum space needed for MMIO isn't respected."
			raise Unsupported_Value_Error(self.FULL_NAME, ranges_length, [self.min_addr_space], details)
	
	#this is a concrete method for those peripherals that perform no configuration
	#since making it abstract would force them to implement it as empty anyway
	def config_ip(self, root_path: str, **kwargs) -> None:
		return
