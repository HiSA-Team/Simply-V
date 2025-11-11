from env import *
from busses.nonleafbus import NonLeafBus
from utils import *
from busses_factory import Busses_Factory
from singleton import SingletonABCMeta

#Only one MBUS should be created
class MBus(NonLeafBus, metaclass=SingletonABCMeta):

	def __init__(self, mbus_data_dict: dict, mbus_file_name: str, axi_addr_width: int, axi_data_width: int, \
			asgn_addr_ranges: int, asgn_range_base_addr: list, asgn_range_addr_width: list, clock_domain: str):

		self.LEGAL_PERIPHERALS: list[str] = ["BRAM", "DM", "PLIC"]
		self.LEGAL_PERIPHERALS_HPC: list[str] = self.LEGAL_PERIPHERALS + ["DDR4", "HLS"]
		self.LEGAL_BUSSES: list[str] = ["PBUS"]
		self.LEGAL_BUSSES_HPC: list[str] = self.LEGAL_BUSSES + ["HBUS"]

		self.VALID_PROTOCOLS: list[str] = ["AXI4", "DISABLE"]

		# init NonLeafBus object
		super().__init__("MBUS", "MBUS", mbus_file_name, axi_addr_width, axi_data_width, \
				   asgn_addr_ranges, asgn_range_base_addr, asgn_range_addr_width, clock_domain)


		try:
			self.check_assign_params(mbus_data_dict)
		except ValueError as e:
			self.logger.simply_v_crash(f"Invalid value type: {e}")

		if(self.PROTOCOL == "DISABLE"):
			return

		self.check_intra()
		self.check_inter()

		env_global = Env.get_instance()

		if(env_global.get_soc_profile()=="embedded"):
			self.check_peripherals(self.LEGAL_PERIPHERALS)
			self.check_busses(self.LEGAL_BUSSES)
		elif(env_global.get_soc_profile()=="hpc"):
			self.check_peripherals(self.LEGAL_PERIPHERALS_HPC)
			self.check_busses(self.LEGAL_BUSSES_HPC)


	def check_assign_params(self, data_dict):
		super().check_assign_params(data_dict)


	def check_intra(self):
		#check params interactions of BUS object
		super().check_intra()

		simply_v_crash = self.logger.simply_v_crash
		
		if self.PROTOCOL not in self.VALID_PROTOCOLS:
			simply_v_crash(f"Unsupported protocol: {self.PROTOCOL}")

	def check_inter(self):
		super().check_inter()

	def init_configurations(self):
		# generate all the hierarchy
		self.generate_children()
		# put reachability values in the nodes based on the hierarchy created
		self.add_reachability()
		# init clock domains
		self.init_clock_domains()
		# check configuration of clock domains on this bus
		self.check_clock_domains()

	#To be called after generating children of this node (init_clock_domains uses this node list of children)
	def check_clock_domains(self):
		simply_v_crash = self.logger.simply_v_crash
		#Add MBus custom checks
		failed_checks = []
		peripherals_to_check = ["PLIC", "BRAM", "DM"]
		for p in peripherals_to_check:
			ret = self.clock_domains.is_in_domain(p, self.CLOCK_DOMAIN)
			if(not ret):
				failed_checks.append(p)

		if (len(failed_checks) != 0):
			simply_v_crash(f"-{', '.join(failed_checks)}- need to be configured with MAIN CLOCK DOMAIN ({self.CLOCK_DOMAIN})")
