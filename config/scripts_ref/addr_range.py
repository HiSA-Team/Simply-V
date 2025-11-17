class Addr_Range():
	def __init__(self, base_name: str, range_name: str, range_base_addr: int, range_addr_width: int, \
				clock_domain: str, clock_frequency: int):

		self.RANGE_NAME: str = range_name
		#This is just "RANGE_NAME" but without any suffixes ex. NAME="TIM_0" -> BASE_NAME="TIM"
		self.BASE_NAME: str = base_name
		self.RANGE_BASE_ADDR : int = range_base_addr 
		self.RANGE_ADDR_WIDTH : int = range_addr_width 
		self.RANGE_END_ADDR = self.RANGE_BASE_ADDR + ~(~1 << (self.RANGE_ADDR_WIDTH -1)) + 1 
		self.CLOCK_DOMAIN: str = clock_domain
		self.CLOCK_FREQUENCY: int = clock_frequency

		# list of busses that can reach this node
		self.REACHABLE_FROM : list[str] = []
		
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
		return not (self.RANGE_END_ADDR < addr_range.RANGE_BASE_ADDR or 
					self.RANGE_BASE_ADDR > addr_range.RANGE_END_ADDR)

	def __repr__(self):
		return f"{self.RANGE_NAME}: 0x{self.RANGE_BASE_ADDR:X}-0x{self.RANGE_END_ADDR:X}"
