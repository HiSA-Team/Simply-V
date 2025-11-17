from busses.bus import Bus
from addr_range import Addr_Range
from peripherals.peripheral import Peripheral

class PBus(Bus):
	LEGAL_PERIPHERALS = ("UART", "GPIO_out", "GPIO_in", "TIM")
	VALID_PROTOCOLS = ("AXI4LITE")

	def __init__(self, data_dict: dict, asgn_addr_range: list[Addr_Range]):

		axi_addr_width = 32
		axi_data_width = 32
		
		super().__init__(data_dict, asgn_addr_range, axi_addr_width, axi_data_width)

		self.check_assign_params(pbus_data_dict)

		if(self.PROTOCOL == "DISABLE"):
			return

		self.check_intra()

		self.check_inter()

		self.check_peripherals(self.LEGAL_PERIPHERALS)


	def check_assign_params(self, data_dict):
		super().check_assign_params(data_dict)

		#assert PBUS has only 1 master
		if(self.NUM_SI != 1):
			self.logger.simply_v_crash(f"NUM_SI must be 1 for PBUS, not {self.NUM_SI}")


	def check_intra(self):
		#check params interactions of BUS object
		super().check_intra()

		if self.PROTOCOL not in self.VALID_PROTOCOLS:
			self.logger.simply_v_crash(f"Unsupported protocol: {self.PROTOCOL}")

	def check_inter(self):
		super().check_inter()


	#COMPOSITE INTERFACE IMPLEMENTATION

	def init_configurations(self):
		# generate all the hierarchy
		self.generate_children()
		# put reachability values in the nodes based on the hierarchy created
		self.add_reachability()

	def generate_children(self):
		for i in range(len(self.RANGE_NAMES)):
			node = self.peripherals_factory.create_peripheral(self.RANGE_NAMES[i], self.ADDR_RANGES, \
						self.RANGE_BASE_ADDR[i:(i+self.ADDR_RANGES)], \
						self.RANGE_ADDR_WIDTH[i:(i+self.ADDR_RANGES)], \
						self.CLOCK_DOMAIN)

			self.children_peripherals.append(node)

			# all the peripherals of PBUS are reachable from PBUS and everything that
			# can reach PBUS
		super().add_reachability()

	def get_busses(self) -> list["Bus"]:
		return [self]


	def check_clock_domains(self):
		return

	def init_clock_domains(self):
		return
