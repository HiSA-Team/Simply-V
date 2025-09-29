from nonleafbus import NonLeafBus

class HBus(NonLeafBus):
	def __init__(self, hbus_data_dict: dict, hbus_file_name: str, asgn_addr_ranges: int, \
			asgn_range_base_addr: list, asgn_range_addr_width: list, \
			axi_addr_width: int ,father: NonLeafBus, clock: int):


		self.father = father
		self.LEGAL_PERIPHERALS: list[str] = ["DDR", "MBUS"]
		self.VALID_PROTOCOLS: list[str] = ["AXI4", "DISABLE"]

		self.LOOPBACK: int
		axi_data_width = 512
		
		# init Bus object
		super().__init__(hbus_data_dict, hbus_file_name, axi_addr_width, axi_data_width, \
				   asgn_addr_ranges, asgn_range_base_addr, asgn_range_addr_width, clock)

		try:
			self.check_assign_params(hbus_data_dict)
		except ValueError as e:
			self.logger.simply_v_crash(f"Invalid value type: {e}")

		if(self.PROTOCOL == "DISABLE"):
			return

		self.check_intra()
			
		## always check inter before adding the loopback
		## so the checks don't break
		self.check_inter()
	
		if (self.LOOPBACK == 1):
			self.father.father_enable_loopback()
			self.child_enable_loopback()

		self.check_peripherals(self.LEGAL_PERIPHERALS)

	
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
		
		hbus_range_addr_bits = self.ASGN_RANGE_BASE_ADDR[0].bit_length()

		mbus_range_1_base_addr = 0
		mbus_range_1_addr_width = hbus_range_addr_bits - 1 
		mbus_range_1_end_addr = self.compute_range_end_addr(mbus_range_1_base_addr, mbus_range_1_addr_width)

		# this is the range of all the addresses AFTER the range of HBUS
		mbus_range_2_base_addr = (1 << (self.ADDR_WIDTH-1))
		mbus_range_2_addr_width = self.ADDR_WIDTH - 1
		mbus_range_2_end_addr = (1 << self.ADDR_WIDTH) - 1

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


	def check_assign_params(self, data_dict):
		super().check_assign_params(data_dict)

		if("LOOPBACK" not in data_dict):
			self.LOOPBACK = 0
		else:
			self.LOOPBACK = int(data_dict["LOOPBACK"])

	
	def check_intra(self):
		#check params interactions of BUS object
		super().check_intra()

		simply_v_crash = self.logger.simply_v_crash
		
		if self.PROTOCOL not in self.VALID_PROTOCOLS:
			simply_v_crash(f"Unsupported protocol: {self.PROTOCOL}")

		if (self.LOOPBACK == 1):
			if (self.ADDR_RANGES != 1):
				simply_v_crash(f"ADDR_RANGES must be 1 when activating LOOPBACK")

			if (self.PROTOCOL == "AXI4"):
				for width in self.RANGE_ADDR_WIDTH:
					if width <= 12:
						simply_v_crash(f"When enabling LOOPBACK all the RANGE_ADDR_WIDTH "
										"should be at least 13 when using AXI4 "
										"the HBUS uses internally this extra bit "
										"to rearrange RANGES in order to accomodate "
										"the loopback configuration")

		# Check valid clock domains
		self.logger.simply_v_warning("HBUS check_intra isn't fully implemented (missing clocks checks)")
	

	def check_inter(self):
		super().check_inter()

	def generate_children(self):
		return

