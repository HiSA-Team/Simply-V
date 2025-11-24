class Addr_Range():
	def __init__(self, base_name: str, range_name: str, range_base_addr: int, range_addr_width: int):

		self.RANGE_NAME: str = range_name
		#This is just "RANGE_NAME" but without any suffixes ex. NAME="TIM_0" -> BASE_NAME="TIM"
		self.BASE_NAME: str = base_name
		self.RANGE_BASE_ADDR : int = range_base_addr 
		self.RANGE_ADDR_WIDTH : int = range_addr_width 
		
		least_significant_zeroes = ~(~ 1 << (self.RANGE_ADDR_WIDTH-1))

		#RANGE_BASE_ADDR need to have "n" consecutive least significant bits equal to 0
		#where "n" is equal to RANGE_ADDR_WIDTH
		if (self.RANGE_BASE_ADDR & least_significant_zeroes) != 0:
			raise ValueError(f"BASE_ADDR not compatible with RANGE_ADDR_WIDTH in {self.RANGE_NAME}")

		#RANGE_END_ADDR is the first address outside the addressable range
		self.RANGE_END_ADDR = self._compute_end_addr(self.RANGE_BASE_ADDR, self.RANGE_ADDR_WIDTH)


		# list of busses that can reach this node
		self.REACHABLE_FROM : list[str] = []

	def _compute_end_addr(self, base_addr: int, addr_width: int):
		return base_addr + ~(~ 1 << (addr_width-1)) + 1

	def split(self) -> "Addr_Range":
		first_base = self.RANGE_BASE_ADDR
		first_width = self.RANGE_ADDR_WIDTH - 1
		first_end = self._compute_end_addr(first_base, first_width)

		second_base = first_end
		second_width = self.RANGE_ADDR_WIDTH - 1

		# change parameters
		self.RANGE_ADDR_WIDTH = first_width
		self.RANGE_END_ADDR = first_end

		second_range = Addr_Range(self.BASE_NAME, self.RANGE_NAME, second_base, second_width)
		#preserve reachability
		second_range.add_list_to_reachable(self.REACHABLE_FROM)
		return second_range
		
	def add_to_reachable(self, bus_name: str):
		# in case of duplicates
		if(bus_name in self.REACHABLE_FROM):
			return

		self.REACHABLE_FROM.append(bus_name)
	
	def add_list_to_reachable(self, list_of_names: list[str]):
		for bus_name in list_of_names:
			# in case of duplicates
			if(bus_name in self.REACHABLE_FROM):
				continue
			self.REACHABLE_FROM.append(bus_name)

	#Check if the address space of this node contains the address space passed
	def __contains__(self, addr_range: "Addr_Range") -> bool:
		return (self.RANGE_BASE_ADDR <= addr_range.RANGE_BASE_ADDR and
				self.RANGE_END_ADDR >= addr_range.RANGE_END_ADDR)

	#Check if the address space of this node is contained the address space passed
	def is_contained(self, addr_range: "Addr_Range") -> bool:
		return ((addr_range.RANGE_BASE_ADDR <= self.RANGE_BASE_ADDR) and 
		   (self.RANGE_END_ADDR <= addr_range.RANGE_END_ADDR))

	def overlaps(self, addr_range: "Addr_Range") -> bool:
		return not (self.RANGE_END_ADDR <= addr_range.RANGE_BASE_ADDR or 
					self.RANGE_BASE_ADDR >= addr_range.RANGE_END_ADDR)

	def __repr__(self):
		return f"{self.RANGE_NAME}: 0x{self.RANGE_BASE_ADDR:X}-0x{self.RANGE_END_ADDR:X} REACHABLE {self.REACHABLE_FROM}"
