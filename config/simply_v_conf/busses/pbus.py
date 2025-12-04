from .leafbus import LeafBus
from .bus import Bus
from general.addr_range import Addr_Ranges

class PBus(LeafBus):
	LEGAL_PERIPHERALS = Bus.LEGAL_PERIPHERALS + ("UART", "GPIO_out", "GPIO_in", "TIM")
	LEGAL_PROTOCOLS = Bus.LEGAL_PROTOCOLS + ("AXI4LITE",)

	def __init__(self, base_name: str, data_dict: dict, asgn_addr_ranges: Addr_Ranges, clock_domain: str, 
					clock_frequency: int):


		axi_addr_width = 32
		axi_data_width = 32
		
		super().__init__(base_name, data_dict, asgn_addr_ranges, axi_addr_width, axi_data_width, clock_domain, clock_frequency)

		#check NUM_SI
		if self.NUM_SI != 1:
			self.logger.simply_v_crash(f"Invalid number of NUM_SI ({self.NUM_SI}) in {self.FULL_NAME}")
