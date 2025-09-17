import bus

class MBus(Bus):
	def __init__(self, mbus_file_name: str, range_addr_width: int, data_width: int, addr_width: int, clock: int):
		self.LEGAL_PERIPHERALS: list = []
		self.PROTOCOL: str = "AXI4"
		self.ADDR_WIDTH: int = addr_width
		self.DATA_WIDTH: int = data_width
		self.RANGE_CLOCK_DOMAINS: list = []

		# MBUS has a base address of 0 as a convention
		base_addr = 0
		# MBUS has an addr ranges of 1 as a convention
		addr_ranges = 1
		
		# init Bus object
		super().__init__(mbus_file_name, base_addr, addr_ranges, range_addr_width, clock)



