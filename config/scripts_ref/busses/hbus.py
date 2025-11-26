from busses.nonleafbus import NonLeafBus
from busses.bus import Bus
from addr_range import Addr_Ranges


class HBus(NonLeafBus):
	LEGAL_PERIPHERALS = Bus.LEGAL_PERIPHERALS + ("DDR4",)
	LEGAL_BUSSES = NonLeafBus.LEGAL_BUSSES +  ("MBUS",)
	LEGAL_PROTOCOLS = Bus.LEGAL_PROTOCOLS + ("AXI4",)

	def __init__(self, base_name: str, data_dict: dict, asgn_addr_ranges: Addr_Ranges, clock_domain: str, 
					clock_frequency: int, axi_addr_width: int, father: NonLeafBus):
		axi_data_width = 512
		
		# init NonleafBus object
		super().__init__(base_name, data_dict, asgn_addr_ranges, axi_addr_width, axi_data_width, clock_domain,
						clock_frequency, father)


	def check_clock_domains(self):
		return
