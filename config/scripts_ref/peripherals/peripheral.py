from addr_range import Addr_Range

class Peripheral():
	def __init__(self, asgn_addr_ranges: list[Addr_Range]):

		self.IS_A_MEMORY: bool
		self.asng_addr_ranges = asgn_addr_ranges

		# need to check for DDR clock

	#delegate all unsupported functions to the address ranges
	def __getattr__(self, name):
		return getattr(self._inner, name)
