from busses.leafbus import LeafBus, Bus
from addr_range import Addr_Range
from peripherals.peripheral import Peripheral

class PBus(LeafBus):
	LEGAL_PERIPHERALS = Bus.LEGAL_PERIPHERALS + ("UART", "GPIO_out", "GPIO_in", "TIM")
	LEGAL_PROTOCOLS = Bus.LEGAL_PROTOCOLS + ("AXI4LITE",)

	def __init__(self, range_name: str, data_dict: dict, asgn_addr_range: list[Addr_Range], clock_domain: str, 
					clock_frequency: int):

		axi_addr_width = 32
		axi_data_width = 32
		
		super().__init__(range_name, data_dict, asgn_addr_range, axi_addr_width, axi_data_width, clock_domain, clock_frequency)


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

