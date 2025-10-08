from bus import Bus

class NonLeafBus(Bus):
	def __init__(self, name:str, mbus_file_name: str, axi_addr_width: int, axi_data_width: int, \
			asgn_addr_ranges: int, asgn_range_base_addr: list, asgn_range_addr_width: list, clock: int):

		self.RANGE_CLOCK_DOMAINS: list[int] = []
		self.children_busses: list[Bus] = []
		self.children_nonleaf_busses: list[NonLeafBus] = []
		self.num_loopbacks: int = 0

		# init Bus object
		super().__init__(name, mbus_file_name, axi_addr_width, axi_data_width, \
				asgn_addr_ranges, asgn_range_base_addr, asgn_range_addr_width, clock)


	def check_intra(self):
		super().check_intra()

		simply_v_crash = self.logger.simply_v_crash

		if self.NUM_MI != len(self.RANGE_CLOCK_DOMAINS):
			simply_v_crash(f"The NUM_MI value {self.NUM_MI} does not match the number of RANGE_CLOCK_DOMAINS")


	def check_assign_params(self, data_dict: dict):
		simply_v_crash = self.logger.simply_v_crash

		super().check_assign_params(data_dict)
		if("RANGE_CLOCK_DOMAINS" not in data_dict):
			simply_v_crash("RANGE_CLOCK_DOMAINS is mandatory")
			
		self.RANGE_CLOCK_DOMAINS = [int(x) for x in data_dict["RANGE_CLOCK_DOMAINS"].split(" ")]
	
	def child_enable_loopback(self):

		## Need to set ADDR_RANGES to 2
		## reconstruct RANGE_BASE_ADDR, RANGE_ADDR_WIDTH and RANGE_END_ADDR in order to use
		## ADDR_RANGES
		## place MBus as a slave, assign it 2 RANGE_BASE_ADDR, RANGE_ADDR_WIDTH and RANGE_END_ADDR
		## according to everything outside of your addr ranges (ASGN variables)


		self.ADDR_RANGES = 2
		self.NUM_MI += 1

		temp_base_addresses = []
		temp_addr_widths = []
		temp_end_addresses = []

		for i in range(len(self.RANGE_NAMES)):
			first_base = self.RANGE_BASE_ADDR[i]

			first_width = self.RANGE_ADDR_WIDTH[i] - 1
			second_width = self.RANGE_ADDR_WIDTH[i] - 1
			
			first_end = self.compute_range_end_addr(first_base, first_width) 

			second_base = first_end + 1 

			temp_base_addresses.append(first_base)
			temp_base_addresses.append(second_base)
			temp_addr_widths.append(first_width)
			temp_addr_widths.append(second_width)

		# insert the MBUS addr ranges
		self.RANGE_NAMES.append("MBUS")

		# this is the range of all the addresses BEFORE the range of HBUS
		
		mbus_range_1_base_addr = 0
		mbus_range_1_addr_width = min(self.ASGN_RANGE_BASE_ADDR).bit_length() - 1 
		mbus_range_1_end_addr = self.compute_range_end_addr(mbus_range_1_base_addr, mbus_range_1_addr_width)

		# this is the range of all the addresses AFTER the range of HBUS
		mbus_range_2_base_addr = max(self.ASGN_RANGE_END_ADDR) + 1
		mbus_range_2_addr_width = self.ASGN_RANGE_ADDR_WIDTH[0]
		mbus_range_2_end_addr = self.compute_range_end_addr(mbus_range_2_base_addr, mbus_range_2_addr_width)

		self.logger.simply_v_warning(
			f"To accommodate ADDR_WIDTH, constrain the base address of the MBUS "
			f"starting AFTER the address range of HBUS is {mbus_range_2_base_addr:#010x} "
			f"and its end address is {mbus_range_2_end_addr:#010x}, so make sure to allocate "
			f"all the slaves AFTER the HBUS in this range"
		)

		temp_base_addresses.extend([mbus_range_1_base_addr, mbus_range_2_base_addr])
		temp_addr_widths.extend([mbus_range_1_addr_width, mbus_range_2_addr_width])
		temp_end_addresses.extend([mbus_range_1_end_addr, mbus_range_2_end_addr])

		self.RANGE_BASE_ADDR = temp_base_addresses
		self.RANGE_ADDR_WIDTH = temp_addr_widths 
		self.RANGE_END_ADDR = self.compute_range_end_addresses(self.RANGE_BASE_ADDR, self.RANGE_ADDR_WIDTH)


	def father_enable_loopback(self):
		self.logger.simply_v_warning("NEED TO CHECK FATHER ENABLE LOOPBACK IMPLEMENTATION (wrong name convention)")
		self.MASTER_NAMES.append("HBUS_" + str(self.num_loopbacks))
		self.num_loopbacks += 1
		self.NUM_SI += 1

