from addr_range import Addr_Range
from busses.bus import Bus
from env import *
from busses.nonleafbus import NonLeafBus
from singleton import SingletonABCMeta

#Only one MBUS should be created
class MBus(NonLeafBus, metaclass=SingletonABCMeta):
	env_global = Env.get_instance()

	LEGAL_PERIPHERALS = Bus.LEGAL_PERIPHERALS + ("BRAM", "DM", "PLIC")
	LEGAL_BUSSES = NonLeafBus.LEGAL_BUSSES +  ("PBUS",)
	LEGAL_PROTOCOLS = Bus.LEGAL_PROTOCOLS + ("AXI4",)

	if env_global.get_soc_profile()=="hpc":
		LEGAL_PERIPHERALS = LEGAL_PERIPHERALS + ("DDR4", "HLS")
		LEGAL_BUSSES = LEGAL_BUSSES + ("HBUS",)


	def __init__(self, range_name:str, data_dict: dict, asgn_addr_range: list[Addr_Range], clock_domain: str, 
				clock_frequency: int, axi_addr_width: int, axi_data_width: int,):

		# init NonLeafBus object
		super().__init__(range_name, data_dict, asgn_addr_range, axi_addr_width, axi_data_width, clock_domain, clock_frequency)

	
	def init_configurations(self):
		# sanitize all the addr_ranges
		self.sanitize_addr_ranges()
		# check legals busses/peripherals
		self.check_legals()
		# activate loopbacks
		self.activate_loopback()
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
			simply_v_crash(f"-{', '.join(failed_checks)} need to be configured with MAIN CLOCK DOMAIN ({self.CLOCK_DOMAIN})")
