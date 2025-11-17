from addr_range import Addr_Range
from env import *
from busses.nonleafbus import NonLeafBus
from singleton import SingletonABCMeta

#Only one MBUS should be created
class MBus(NonLeafBus, metaclass=SingletonABCMeta):
	env_global = Env.get_instance()
	LEGAL_PERIPHERALS = ("BRAM", "DM", "PLIC")
	LEGAL_PERIPHERALS_HPC = LEGAL_PERIPHERALS + ("DDR4", "HLS")
	LEGAL_BUSSES = ("PBUS")
	LEGAL_BUSSES_HPC = LEGAL_BUSSES + ("HBUS")
	VALID_PROTOCOLS = ("AXI4")

	def __init__(self, data_dict: dict, asgn_addr_range: list[Addr_Range], axi_addr_width: int, axi_data_width: int):

		# init NonLeafBus object
		super().__init__(data_dict, asgn_addr_range, axi_addr_width, axi_data_width)


		self.check_intra()
		self.check_inter()

		if(self.env_global.get_soc_profile()=="embedded"):
			self.check_peripherals(self.LEGAL_PERIPHERALS)
			self.check_busses(self.LEGAL_BUSSES)
		elif(self.env_global.get_soc_profile()=="hpc"):
			self.check_peripherals(self.LEGAL_PERIPHERALS_HPC)
			self.check_busses(self.LEGAL_BUSSES_HPC)


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
