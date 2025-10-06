from utils import *
from mbus import MBus
from logger import Logger
from pprint import pprint

class SimplyV:
	def __init__(self, sys_config_file_name: str, mbus_file_name: str, soc_profile: str):
		# defaults
		self.SUPPORTED_CORES : list = ["CORE_PICORV32", "CORE_CV32E40P", "CORE_IBEX", "CORE_MICROBLAZEV_RV32", \
										"CORE_MICROBLAZEV_RV64", "CORE_CV64A6"]
		self.EMBEDDED_SUPPORTED_CLOCKS : list[int] = [10, 20, 50, 100]
		self.HPC_SUPPORTED_CLOCKS : list[int] = [10, 20, 50, 100, 250]
		self.CORE_SELECTOR : str
		self.VIO_RESETN_DEFAULT : int = 1
		self.XLEN : int = 32
		self.PHYSICAL_ADDR_WIDTH : int = 32
		self.MAIN_CLOCK_DOMAIN : int
		self.logger: Logger = Logger(sys_config_file_name)
		self.soc_profile : str = soc_profile
		self.mbus : "MBus"
		
		# read config file
		system_data_dict = parse_csv(sys_config_file_name)

		# check and assign parameters

		try:
			self.check_assign_params(system_data_dict)
		except ValueError as e:
			self.logger.simply_v_crash(f"Invalid value type: {e}")

		# check params interactions
		self.check_intra()

		# Create root node (MBUS)
		axi_addr_width = self.PHYSICAL_ADDR_WIDTH
		axi_data_width = self.XLEN

		# MBUS has an addr_ranges of 1,
		# has a range_base_address of 0 and
		# a range_addr_width of all the PHYSICAL memory as convention
		asgn_addr_ranges = 1
		asgn_range_base_addr = [0]
		asgn_range_addr_width = [self.PHYSICAL_ADDR_WIDTH]
		clock = self.MAIN_CLOCK_DOMAIN

		mbus_data_dict = parse_csv(mbus_file_name)

		self.mbus = MBus(mbus_data_dict, mbus_file_name, axi_addr_width, axi_data_width, asgn_addr_ranges, \
								asgn_range_base_addr, asgn_range_addr_width, clock)

		print("PERIPHERALS:")
		peripherals =  self.mbus.get_peripherals()
		pprint([p.__dict__ for p in peripherals])

		pprint(vars(self.mbus))


	def check_assign_params(self, data_dict: dict):
		simply_v_crash = self.logger.simply_v_crash

		if ("CORE_SELECTOR" not in data_dict):
			simply_v_crash("CORE_SELECTOR is mandatory")

		self.CORE_SELECTOR = data_dict["CORE_SELECTOR"]
		
		if (self.CORE_SELECTOR not in self.SUPPORTED_CORES):
			simply_v_crash("CORE_SELECTOR unsupported")

		if ("VIO_RESETN_DEFAULT" in data_dict):
			self.VIO_RESETN_DEFAULT = int(data_dict["VIO_RESETN_DEFAULT"])
			if ((self.VIO_RESETN_DEFAULT != 0) and (self.VIO_RESETN_DEFAULT != 1)):
				simply_v_crash("VIO_RESETN_DEFAULT unexpected value")
	
		if ("XLEN" in data_dict):
			self.XLEN = int(data_dict["XLEN"])
			if ((self.XLEN != 32) and (self.XLEN != 64)):
				simply_v_crash("XLEN unexpected value")

		if ("PHYSICAL_ADDR_WIDTH" in data_dict):
			self.PHYSICAL_ADDR_WIDTH = int(data_dict["PHYSICAL_ADDR_WIDTH"])
			if(self.PHYSICAL_ADDR_WIDTH not in range(32,65)):
				simply_v_crash("PHYSICAL_ADDR_WIDTH can't be outside [32,64]")

		if ("MAIN_CLOCK_DOMAIN" not in data_dict):
			simply_v_crash("MAIN_CLOCK_DOMAIN is mandatory")

		self.MAIN_CLOCK_DOMAIN = int(data_dict["MAIN_CLOCK_DOMAIN"])


	def check_intra(self):
		simply_v_crash = self.logger.simply_v_crash

		# check XLEN and PHYSICAL_ADDR_WIDTH interaction
		if((self.XLEN == 32) and (self.PHYSICAL_ADDR_WIDTH != 32)):
			simply_v_crash("PHYSICAL_ADDR_WIDTH doesn't match when XLEN = 32")

		# check XLEN with MicroblazeV type interaction
		if ((self.CORE_SELECTOR == "CORE_MICROBLAZEV_RV64" and self.XLEN == 32) or \
			(self.CORE_SELECTOR == "CORE_MICROBLAZEV_RV32" and self.XLEN == 64)):
			simply_v_crash(f"XLEN={self.XLEN} doesn't match {self.CORE_SELECTOR} data width.")

		if((self.XLEN == 64) and ((self.PHYSICAL_ADDR_WIDTH == 32) or (self.PHYSICAL_ADDR_WIDTH > 64))):
			simply_v_crash("PHYSICAL_ADDR_WIDTH should be in range (32,64] when XLEN = 64")

		# check profile and MAIN_CLOCK_DOMAIN interaction
		if (self.soc_profile == "embedded"):
			if (self.MAIN_CLOCK_DOMAIN not in self.EMBEDDED_SUPPORTED_CLOCKS):
				simply_v_crash(f"Unsupported MAIN_CLOCK_DOMAIN value (supported values\
						for {self.soc_profile} profile: {self.EMBEDDED_SUPPORTED_CLOCKS})")
		else: #hpc
			if (self.MAIN_CLOCK_DOMAIN not in self.HPC_SUPPORTED_CLOCKS):
				simply_v_crash(f"Unsupported MAIN_CLOCK_DOMAIN value (supported values\
						for {self.soc_profile} profile: {self.HPC_SUPPORTED_CLOCKS})")

		## check CORE_SELECTOR and VIO_RESETN_DEFAULT interaction
		if self.CORE_SELECTOR == "CORE_PICORV32" and self.VIO_RESETN_DEFAULT != 0:
			simply_v_crash(f"CORE_PICORV32 only supports VIO_RESETN_DEFAULT = 0! {self.VIO_RESETN_DEFAULT}")
