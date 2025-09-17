import node

class Bus(Node):
	def __init__(self, file_name: str, base_addr: int, addr_ranges: int, \
			range_addr_width: int, clock: int):

		self.ID_WIDTH			 : int = 4		# ID Data Width for MI and SI (a subset of it is used by the Interfaces Thread IDs)
		self.NUM_MI				 : int = 0 		# Master Interface (MI) Number
		self.NUM_SI				 : int = 0 		# Slave Interface (SI) Number
		self.MASTER_NAMES        : list = []    # List of names of masters connected to the bus
		self.RANGE_NAMES         : list = []    # List of names of slaves connected to the bus
		self.children : list
		
		# init Node object
		super().__init__(addr_ranges, base_addr, range_addr_width, clock)

		data_dict = parse_csv(file_name)

		#check params







