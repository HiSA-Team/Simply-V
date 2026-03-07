# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is class implements the peripheral bus
# it's a LeafBus so it can only hold peripherals nodes

from .leafbus import LeafBus
from .bus import Bus
from general.addr_range import Addr_Ranges
from general.error import Unsupported_Value_Error

class PBus(LeafBus):
	LEGAL_PERIPHERALS = Bus.LEGAL_PERIPHERALS + ("UART", "GPIOOUT", "GPIOIN", "TIM")
	LEGAL_PROTOCOLS = Bus.LEGAL_PROTOCOLS + ("AXI4LITE",)

	def __init__(self, base_name: str, data_dict: dict, assigned_addr_ranges: Addr_Ranges, clock_domain: str,
					clock_frequency: int):

		# The RTL implementation assumes PBUS addr_width and data_width as fixed values, so since they can't be
		# configured we hardcode, but still specify, them, in order to adhere to the "Bus" constructor
		axi_addr_width = 32
		axi_data_width = 32

		super().__init__(base_name, data_dict, assigned_addr_ranges, axi_addr_width, axi_data_width, clock_domain, clock_frequency)

		# check NUM_SI
		if len(self.MASTER_NAMES) != 1:
			raise Unsupported_Value_Error(f"LENGTH OF MASTER_NAMES", len(self.MASTER_NAMES), [1],
										  "PBUS supports only 1 MASTER")
