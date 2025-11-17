from sys import implementation
from busses.nonleafbus import NonLeafBus
from addr_range import Addr_Range
from peripherals.peripheral import Peripheral


class HBus(NonLeafBus):
	VALID_PROTOCOLS = ("AXI4")
	LEGAL_PERIPHERALS = ("DDR4")
	LEGAL_BUSSES = ("MBUS")

	def __init__(self, data_dict: dict, asgn_addr_range: list[Addr_Range], axi_addr_width: int, father: NonLeafBus):
		axi_data_width = 512
		
		# init NonleafBus object
		super().__init__(data_dict, asgn_addr_range, axi_addr_width, axi_data_width)

		self.check_intra()
			
		## always check inter before adding the loopback
		## so the checks don't break on the MBUS addresses
		self.check_inter()

		self.check_peripherals(self.LEGAL_PERIPHERALS)
	
		if (self.LOOPBACK == 1):
			self.father.father_enable_loopback(self.NAME)
			self.child_enable_loopback()
			self.RANGE_CLOCK_DOMAINS.append(father.CLOCK_DOMAIN)

	
	def check_intra(self):
		#check params interactions of BUS object
		super().check_intra()

		simply_v_crash = self.logger.simply_v_crash
		
		if self.PROTOCOL not in self.VALID_PROTOCOLS:
			simply_v_crash(f"Unsupported protocol: {self.PROTOCOL}")

		if (self.LOOPBACK == 1):
			min_base_addr = min(self.ASGN_RANGE_BASE_ADDR)

			# Force base addr to power of 2
			if(not ((min_base_addr & (min_base_addr -1) == 0) and min_base_addr != 0)):
				self.logger.simply_v_crash("When using LOOPBACK base address must be a power of 2")

		# Check valid clock domains
		self.logger.simply_v_warning("HBUS check_intra isn't fully implemented (missing clocks checks)")
	
	def check_inter(self):
		super().check_inter()

	# Need to be called after enabling loopback
	# and generating all the nodes of the tree (generate_children() from MBUS)
	def add_reachability(self):
		# add reachability to your peripherals
		super().add_reachability()

		# If loopback enabled this HBUS can also reach
		# the peripherals in the father bus
		if(self.LOOPBACK == 1):
			#assuming that MBUS ranges are the last 2
			father_base_addr_1 = self.RANGE_BASE_ADDR[-2]
			father_base_addr_2 = self.RANGE_BASE_ADDR[-1]
			father_end_addr_1 = self.RANGE_END_ADDR[-2]
			father_end_addr_2 = self.RANGE_END_ADDR[-1]
			#get all the peripherals and busses of the configuration
			#and check if this HBus can reach them
			peripherals = self.father.get_peripherals()
			busses = self.father.get_busses()
			for p in peripherals:
				if (p.is_contained(father_base_addr_1, father_end_addr_1) or
					p.is_contained(father_base_addr_2, father_end_addr_2)):
					p.add_to_reachable(self.NAME)
					p.add_list_to_reachable(self.REACHABLE_FROM)
			for b in busses:
				if (b.is_contained(father_base_addr_1, father_end_addr_1) or
					b.is_contained(father_base_addr_2, father_end_addr_2)):
					b.add_to_reachable(self.NAME)
					b.add_list_to_reachable(self.REACHABLE_FROM)


	def check_clock_domains(self):
		return
