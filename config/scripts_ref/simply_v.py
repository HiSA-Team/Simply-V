import mbus
import utils
import logging

class SimplyV:
	def __init__(self, sys_config_file_name: str, mbus_file_name: str, soc_profile: str):
		# defaults
		self.SUPPORTED_CORES : list = ["CORE_PICORV32", "CORE_CV32E40P", "CORE_IBEX", "CORE_MICROBLAZEV", "CORE_CV64A6"]
		self.EMBEDDED_SUPPORTED_CLOCKS : list = [10, 20, 50, 100]
		self.HPC_SUPPORTED_CLOCKS : list = [10, 20, 50, 100, 250]
		self.CORE_SELECTOR : str
		self.VIO_RESETN_DEFAULT : int = 1
		self.XLEN : int = 32
		self.PHYSICAL_ADDR_WIDTH : int = 32
		self.MAIN_CLOCK_DOMAIN : int
		self.soc_profile : str = soc_profile
		self.mbus : Bus

		# read config file
		data_dict = parse_csv(sys_config_file_name)

		# check and assign parameters
		self.check_assign_params(data_dict)

		# Create root node (MBUS)
		range_addr_width = self.PHYSICAL_ADDR_WIDTH
		data_width = self.XLEN
		addr_width = self.PHYSICAL_ADDR_WIDTH
		clock = self.MAIN_CLOCK_DOMAIN

		self.mbus = mbus.MBus(mbus_file_name, range_addr_width, data_width, addr_width, clock)

	def check_assign_params(self, data_dict: dict):
		if ("CORE_SELECTOR" not in data_dict):
			logging.error("CORE_SELECTOR is mandatory")
			exit(1)

		self.CORE_SELECTOR = data_dict["CORE_SELECTOR"]
		
		if (self.CORE_SELECTOR not in self.SUPPORTED_CORES):
			logging.error("CORE_SELECTOR unsupported")
			exit(1)

		if ("VIO_RESETN_DEFAULT" in data_dict):
			self.VIO_RESETN_DEFAULT = int(data_dict["VIO_RESETN_DEFAULT"])
			if ((self.VIO_RESETN_DEFAULT != 0) and (self.VIO_RESETN_DEFAULT != 1)):
				logging.error("VIO_RESETN_DEFAULT unexpected value")
				exit(1)

		if ("XLEN" in data_dict):
			self.XLEN = int(data_dict["XLEN"])
			if ((self.XLEN != 32) and (self.XLEN != 64)):
				logging.error("XLEN unexpected value")
				exit(1)

		if ("PHYSICAL_ADDR_WIDTH" in data_dict):
			self.PHYSICAL_ADDR_WIDTH = int(data_dict["PHYSICAL_ADDR_WIDTH"])
			if(self.PHYSICAL_ADDR_WIDTH < 32):
				logging.error("PHYSICAL_ADDR_WIDTH can't be less then 32")
				exit(1)

			if((self.XLEN == 32) and (self.PHYSICAL_ADDR_WIDTH != 32))
				logging.error("PHYSICAL_ADDR_WIDTH doesn't match when XLEN = 32")
				exit(1)

			if((self.XLEN == 64) and ((self.PHYSICAL_ADDR_WIDTH == 32) or (self.PHYSICAL_ADDR_WIDTH > 64)))
				logging.error("PHYSICAL_ADDR_WIDTH should be in range (32,64] when XLEN = 64")
				exit(1)

		if ("MAIN_CLOCK_DOMAIN" not in data_dict):
			logging.error("MAIN_CLOCK_DOMAIN is mandatory")
			exit(1)

		self.MAIN_CLOCK_DOMAIN = data_dict["MAIN_CLOCK_DOMAIN"]

		if (self.soc_profile == "embedded"):
			if (self.MAIN_CLOCK_DOMAIN not in self.EMBEDDED_SUPPORTED_CLOCKS):
				logging.error(f"Unsupported MAIN_CLOCK_DOMAIN value (supported values\
						for {self.soc_profile} profile: {self.EMBEDDED_SUPPORTED_CLOCKS})")
				exit(1)
		else: #hpc
			if (self.MAIN_CLOCK_DOMAIN not in self.HPC_SUPPORTED_CLOCKS):
				logging.error(f"Unsupported MAIN_CLOCK_DOMAIN value (supported values\
						for {self.soc_profile} profile: {self.HPC_SUPPORTED_CLOCKS})")
				exit(1)



		
		

		
