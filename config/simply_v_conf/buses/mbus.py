# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the class used to define the "MBus"
# the MBus is a singleton and is the root of the tree hierarchy
# "Simply_V" creates it and uses it as a way to interact with the whole
# nodes hierarchy.
# "Simply_V" calls the "init_configurations" functions to trigger
# all the recursive checks and configuration of the whole hierarchy

from general.addr_range import Addr_Ranges
from .bus import Bus
from general.env import Env
from .nonleafbus import NonLeafBus
from general.singleton import SingletonABCMeta

#Only one MBUS should be created
class MBus(NonLeafBus, metaclass=SingletonABCMeta):
	env_global = Env.get_instance()

	LEGAL_PERIPHERALS = Bus.LEGAL_PERIPHERALS + ("BRAM", "DMMEM", "PLIC")
	LEGAL_BUSES = NonLeafBus.LEGAL_BUSES +  ("PBUS",)
	LEGAL_PROTOCOLS = Bus.LEGAL_PROTOCOLS + ("AXI4",)

	if env_global.get_soc_profile()=="hpc":
		LEGAL_PERIPHERALS = LEGAL_PERIPHERALS + ("DDR4CH", "HLSCONTROL", "CDMA")
		LEGAL_BUSES = LEGAL_BUSES + ("HBUS",)


	def __init__(self, base_name:str, data_dict: dict, asgn_addr_ranges: Addr_Ranges, clock_domain: str, 
				clock_frequency: int, axi_addr_width: int, axi_data_width: int):

		# init NonLeafBus object
		super().__init__(base_name, data_dict, asgn_addr_ranges, axi_addr_width, 
				axi_data_width, clock_domain, clock_frequency, None)

	
	def init_configurations(self):
		# sanitize all the addr_ranges
		self.sanitize_addr_ranges()
		# check legals buses/peripherals
		self.check_legals()
		# put reachability values in the nodes based on the hierarchy created
		self.add_reachability()
		# check configuration of clock domains on this bus
		self.check_clock_domains()

	# extend default clocks checks with custom ones
	def check_clock_domains(self):
		failed_checks = []
		peripherals_to_check = ["PLIC", "BRAM", "DMMEM"]
		for children in self._children_peripherals:
			if (children.FULL_NAME in peripherals_to_check):
				if(children.CLOCK_DOMAIN != self.CLOCK_DOMAIN):
					failed_checks.append(children.CLOCK_DOMAIN)

		if (len(failed_checks) != 0):
			raise ValueError(f"-{', '.join(failed_checks)} need to be configured with MAIN CLOCK DOMAIN ({self.CLOCK_DOMAIN})")

		super().check_clock_domains()
