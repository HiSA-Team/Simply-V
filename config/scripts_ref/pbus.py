from bus import Bus
from peripheral import Peripheral

from pprint import pprint

class PBus(Bus):
	def __init__(self, name: str, pbus_data_dict: dict, pbus_file_name: str, asgn_addr_ranges: int, \
			asgn_range_base_addr: list, asgn_range_addr_width: list, clock: int):

		self.LEGAL_PERIPHERALS: list[str] = ["UART", "GPIO_out", "GPIO_in", "TIM"]
		self.VALID_PROTOCOLS: list[str] = ["AXI4LITE", "DISABLE"]

		axi_addr_width = 32
		axi_data_width = 32
		
		super().__init__(name, pbus_file_name, axi_addr_width, axi_data_width, \
				asgn_addr_ranges, asgn_range_base_addr, asgn_range_addr_width, clock)

		self.check_assign_params(pbus_data_dict)

		if(self.PROTOCOL == "DISABLE"):
			return

		self.check_intra()

		self.check_inter()

		self.check_peripherals(self.LEGAL_PERIPHERALS)

		self.generate_children()


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

	def generate_children(self):
		for i, node_name in enumerate(self.RANGE_NAMES):
			node = Peripheral(self.RANGE_NAMES[i], self.ADDR_RANGES, \
						self.RANGE_BASE_ADDR[i:(i+self.ADDR_RANGES)], \
						self.RANGE_ADDR_WIDTH[i:(i+self.ADDR_RANGES)], \
						self.CLOCK)
			pprint(vars(node))
			self.children.append(node)
