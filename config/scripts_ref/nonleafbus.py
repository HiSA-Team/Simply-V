from bus import Bus

class NonLeafBus(Bus):
	def __init__(self, data_dict: dict, mbus_file_name: str, axi_addr_width: int, axi_data_width: int, \
			asgn_addr_ranges: int, asgn_range_base_addr: list, asgn_range_addr_width: list, clock: int):

		self.RANGE_CLOCK_DOMAINS: list[int] = []
		self.num_loopbacks: int = 0

		# init Bus object
		super().__init__(mbus_file_name, axi_addr_width, axi_data_width, \
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
	

	def father_enable_loopback(self):
		self.MASTER_NAMES.append("HBUS_" + str(self.num_loopbacks))
		self.num_loopbacks += 1
		self.NUM_SI += 1

