# Author: Federica Sarnataro
# Description: This file defines the PSDDR peripheral: the DDR of the Zynq-7000 PS,
#              reached from the MBUS through the PS slave port S_AXI_GP0 (zynq profile only)

from general.addr_range import Addr_Ranges
from .peripheral import Peripheral

class PSDDR(Peripheral):
	# Shared memory with the PS: it is not a memory of the Simply-V CPUs (IS_A_MEMORY stays False,
	# so it is not in their linker script) and it has no HAL driver (HAL_DRIVER stays False)

	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
