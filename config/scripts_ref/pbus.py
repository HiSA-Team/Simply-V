from bus import Bus
import peripheral

class PBus(Bus):
	def __init__(self, data_dict: dict, pbus_file_name: str, range_addr_width: list, base_addr: list, \
			assigned_addr_ranges: int, clock: int):

		self.LEGAL_PERIPHERALS: list = []
		self.PROTOCOL: str = "AXI4LITE"
		self.ADDR_WIDTH: int = 32
		self.DATA_WIDTH: int = 32

		super().__init__(data_dict, pbus_file_name, base_addr, assigned_addr_ranges, range_addr_width, clock)

		self.generate_children()

	def generate_children(self):
		for i, node_name in enumerate(self.RANGE_NAMES):
			node = peripheral.Peripheral(self.RANGE_NAMES[i], self.RANGE_ADDR_WIDTH_LIST[i], \
						self.RANGE_BASE_ADDR_LIST[i], self.ADDR_RANGES, self.CLOCK)
			self.children.append(node)

