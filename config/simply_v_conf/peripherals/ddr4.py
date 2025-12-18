from general.addr_range import Addr_Ranges
from .peripheral import Peripheral

class DDR4(Peripheral):
	LEGAL_CLOCK = 300
	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int,
					channel: int):

		if (clock_frequency != self.LEGAL_CLOCK):
			raise ValueError(f"DDR4 channel {channel} has a wrong clock frequency (must be 300)")

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
		self.IS_A_MEMORY = True
		self.CHANNEL = channel
		self.CAN_GENERATE_CLOCK = True
