from sys import implementation
from busses.nonleafbus import NonLeafBus
from busses.bus import Bus
from addr_range import Addr_Range
from peripherals.peripheral import Peripheral


class HBus(NonLeafBus):
	LEGAL_PERIPHERALS = Bus.LEGAL_PERIPHERALS + ("DDR4",)
	LEGAL_BUSSES = NonLeafBus.LEGAL_BUSSES +  ("MBUS",)
	LEGAL_PROTOCOLS = Bus.LEGAL_PROTOCOLS + ("AXI4",)

	def __init__(self, range_name: str, data_dict: dict, asgn_addr_range: list[Addr_Range], clock_domain: str, 
					clock_frequency: int, axi_addr_width: int, father: NonLeafBus):
		axi_data_width = 512
		
		# init NonleafBus object
		super().__init__(range_name, data_dict, asgn_addr_range, axi_addr_width, axi_data_width, clock_domain, clock_frequency, father)


	
	def check_intra(self):
		#check params interactions of BUS object
		super().check_intra()

		simply_v_crash = self.logger.simply_v_crash
		
		if self.PROTOCOL not in self.VALID_PROTOCOLS:
			simply_v_crash(f"Unsupported protocol: {self.PROTOCOL}")

		if (self.LOOPBACK == True):
			min_base_addr = min(self.ASGN_RANGE_BASE_ADDR)

			# Force base addr to power of 2
			if(not ((min_base_addr & (min_base_addr -1) == 0) and min_base_addr != 0)):
				self.logger.simply_v_crash("When using LOOPBACK base address must be a power of 2")

		# Check valid clock domains
		self.logger.simply_v_warning("HBUS check_intra isn't fully implemented (missing clocks checks)")


	def check_clock_domains(self):
		return
