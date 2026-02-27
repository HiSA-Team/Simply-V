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
from general.error import Conflict_Error

#Only one MBUS should be created
class MBus(NonLeafBus, metaclass=SingletonABCMeta):

	LEGAL_PERIPHERALS = Bus.LEGAL_PERIPHERALS + ("BRAM", "DMMEM", "PLIC", "CLINT", "CDMA")
	LEGAL_BUSES = NonLeafBus.LEGAL_BUSES +  ("PBUS",)
	LEGAL_PROTOCOLS = Bus.LEGAL_PROTOCOLS + ("AXI4",)

	DDR4_LEGAL_CHANNELS = (1,)

	def __init__(self, base_name:str, data_dict: dict, assigned_addr_ranges: Addr_Ranges, clock_domain: str,
				clock_frequency: int, axi_addr_width: int, axi_data_width: int):

		# init NonLeafBus object
		super().__init__(base_name, data_dict, assigned_addr_ranges, axi_addr_width,
				axi_data_width, clock_domain, clock_frequency, None)
		# Env is the class that manages all the "settings.sh" related values (project's paths and profile configuration)
		self.env_global = Env.get_instance()

		if self.env_global.get_simply_v_profile()=="hpc":
			self.LEGAL_PERIPHERALS = self.LEGAL_PERIPHERALS + ("DDR4CH", "HLSCONTROL")
			self.LEGAL_BUSES = self.LEGAL_BUSES + ("HBUS",)

		# Parameters used to assert that the bus/peripheral tree is generated and correctly connected
		# (in the case of buses activating the loopback functionality) before doing any check and sanitizaion
		# of the configuration
		self.tree_generated: bool = False
		self.loopback_activated: bool = False
		self.main_clock_domain_peripherals: list[str] = ["PLIC", "BRAM", "DMMEM"]

		self._RANGE_CLOCK_DOMAINS = data_dict["RANGE_CLOCK_DOMAINS"].copy()

	def init_configurations(self):
		#create children nodes
		self.generate_children()
		# activate all the loopbacks
		self.activate_loopback()
		# sanitize all the addr_ranges
		self.sanitize_addr_ranges()
		# check legals buses/peripherals
		self.check_legals()
		# put reachability values in the nodes based on the hierarchy created
		self.add_reachability()
		# check configuration of clock domains on this bus
		self.check_clock_domains()

	# IMPORTANT:
	# since generate_children and activate_loopback MUST always be executed before all the other configuration functions
	# the MBUS redefines all of them in order to apply this constraint and avoid any possible programming error

	# call the actual implementation and then register it as activated
	def generate_children(self):
		super().generate_children()
		self.tree_generated = True

	# call the actual implementation and then register it as activated
	def activate_loopback(self):
		super().activate_loopback()
		self.loopback_activated = True

	# check constraint and then call the actual implementation
	def sanitize_addr_ranges(self):
		assert self.tree_generated and self.loopback_activated, (
			"sanitize_addr_ranges() failed execution on MBUS since it was "
			"called before generate_children() or activate_loopback()"
		)
		super().sanitize_addr_ranges()

	# check constraint and then call the actual implementation
	def check_legals(self):
		assert self.tree_generated and self.loopback_activated, (
			"check_legals() failed execution on MBUS since it was "
			"called before generate_children() or activate_loopback()"
		)
		super().check_legals()

	# check constraint and then call the actual implementation
	def add_reachability(self):
		assert self.tree_generated and self.loopback_activated, (
			"add_reachability() failed execution on MBUS since it was "
			"called before generate_children() or activate_loopback()"
		)
		super().add_reachability()

	# check constraint and then call the actual implementation
	def check_clock_domains(self):
		assert self.tree_generated and self.loopback_activated, (
			"check_clock_domains() failed execution on MBUS since it was "
			"called before generate_children() or activate_loopback()"
		)

		super().check_clock_domains()
		# extend default clocks checks with custom ones
		failed_checks = []
		# check all the peripherals that are mandated to be on MBUS domain
		for children in self._children_peripherals:
			if (children.BASE_NAME in self.main_clock_domain_peripherals):
				if(children.CLOCK_DOMAIN != self.CLOCK_DOMAIN):
					failed_checks.append(children.FULL_NAME)

		if (len(failed_checks) != 0):
			raise Conflict_Error("PERIPHERAL", "CLOCK_DOMAIN",
								 f"{', '.join(failed_checks)} need to be configured"
								 f"with MAIN CLOCK DOMAIN ({self.CLOCK_DOMAIN}")

