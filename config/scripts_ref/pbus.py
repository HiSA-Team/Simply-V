from bus import Bus
import peripheral
from pprint import pprint

class PBus(Bus):
	def __init__(self, pbus_data_dict: dict, pbus_file_name: str, asgn_addr_ranges: int, asgn_range_base_addr: list, \
			asgn_range_addr_width: list, clock: int):

		self.LEGAL_PERIPHERALS: list = ["UART", "GPIO_out", "GPIO_in", "TIM"]
		self.PROTOCOL: str = "AXI4LITE"
		self.ADDR_WIDTH: int = 32
		self.DATA_WIDTH: int = 32


		super().__init__(pbus_data_dict, pbus_file_name, asgn_addr_ranges, asgn_range_base_addr, \
				   asgn_range_addr_width, clock)

		self.check_intra()

		self.check_peripherals(self.LEGAL_PERIPHERALS)

		self.generate_children()

	def check_intra(self):
		#check params interactions of BUS object
		super().check_intra()
		

	def generate_children(self):
		for i, node_name in enumerate(self.RANGE_NAMES):
			node = peripheral.Peripheral(self.RANGE_NAMES[i], self.ADDR_RANGES, \
						self.RANGE_BASE_ADDR[i:(i+self.ADDR_RANGES)], \
						self.RANGE_ADDR_WIDTH[i:(i+self.ADDR_RANGES)], \
						self.CLOCK)
			pprint(vars(node))
			self.children.append(node)
