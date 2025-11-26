from busses.leafbus import LeafBus, Bus
from addr_range import Addr_Ranges
from peripherals.peripheral import Peripheral

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


	#COMPOSITE INTERFACE IMPLEMENTATION

	def init_configurations(self):
		# generate all the hierarchy
		self.generate_children()
		# put reachability values in the nodes based on the hierarchy created
		self.add_reachability()

	
	def get_busses(self) -> list["Bus"]:
		return [self]


	def check_clock_domains(self):
		return

	def init_clock_domains(self):
		return

	def activate_loopback(self):
		return

