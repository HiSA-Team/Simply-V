# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the class used to define "HBUS" objects
# it inherits from NonLeafBus and just redefines some parameters
# and implement the "check_clock_domains" function

from .nonleafbus import NonLeafBus
from .bus import Bus
from general.addr_range import Addr_Ranges

class HBus(NonLeafBus):
	# Redefyning legals according to HBUS needs
	# they're checked the NonLeafBus "check_legals" function 
	LEGAL_PERIPHERALS = Bus.LEGAL_PERIPHERALS + ("DDR4CH",)
	LEGAL_BUSES = NonLeafBus.LEGAL_BUSES +  ("MBUS",)
	LEGAL_PROTOCOLS = Bus.LEGAL_PROTOCOLS + ("AXI4",)
	# LEGAL_CLOCK_FREQUENCY = 300

	def __init__(self, base_name: str, data_dict: dict, asgn_addr_ranges: Addr_Ranges, clock_domain: str, 
					clock_frequency: int, axi_addr_width: int, father: NonLeafBus):
		# init NonleafBus object
		axi_data_width = 512
		super().__init__(base_name, data_dict, asgn_addr_ranges, axi_addr_width, axi_data_width, clock_domain,
						clock_frequency, father)

		# if (self.CLOCK_FREQUENCY != self.LEGAL_CLOCK_FREQUENCY):
		# 	raise ValueError(f"the bus {self.FULL_NAME} must have clock frequency equal to {self.LEGAL_CLOCK_FREQUENCY}")
		

	def check_clock_domains(self):
		self.logger.simply_v_warning("HBUS clock domains check not implemented")
		return
