from abc import abstractmethod
from pprint import pprint
from typing import Optional
from busses.bus import Bus
from clock_domain import Clock_Domain
from addr_range import Addr_Range
from peripherals.peripheral import Peripheral
from factories.busses_factory import Busses_Factory

class NonLeafBus(Bus):
	busses_factory = Busses_Factory.get_instance()

	def __init__(self, data_dict: dict, asgn_addr_range: list[Addr_Range], axi_addr_width: int, axi_data_width: int, 
					father: Optional["NonLeafBus"] = None):

		self.father = father 
		self.children_busses: list[Bus] = []
		self.clock_domains: Clock_Domain
		self.LOOPBACK = data_dict["LOOPBACK"]

		# init Bus object
		super().__init__(data_dict, asgn_addr_range, axi_addr_width, axi_data_width)

	
	def check_busses(self, legal_busses):
		simply_v_crash = self.logger.simply_v_crash

		for b in self.children_busses:
			if b.BASE_NAME not in legal_busses:
				simply_v_crash(f"Unsupported bus {b.NAME} for this bus")


	def child_enable_loopback(self):

		## Need to set ADDR_RANGES to 2
		## reconstruct RANGE_BASE_ADDR, RANGE_ADDR_WIDTH and RANGE_END_ADDR in order to use
		## ADDR_RANGES
		## place MBus as a slave, assign it 2 RANGE_BASE_ADDR, RANGE_ADDR_WIDTH and RANGE_END_ADDR
		## according to everything outside of your addr ranges (ASGN variables)

		self.ADDR_RANGES = 2
		self.NUM_MI += 1

		temp_base_addresses = []
		temp_addr_widths = []
		temp_end_addresses = []

		for i in range(len(self.RANGE_NAMES)):
			first_base = self.RANGE_BASE_ADDR[i]

			first_width = self.RANGE_ADDR_WIDTH[i] - 1
			second_width = self.RANGE_ADDR_WIDTH[i] - 1
			
			first_end = self.compute_range_end_addr(first_base, first_width) 

			second_base = first_end

			temp_base_addresses.append(first_base)
			temp_base_addresses.append(second_base)
			temp_addr_widths.append(first_width)
			temp_addr_widths.append(second_width)

		# insert the MBUS addr ranges
		self.RANGE_NAMES.append(self.father.NAME)

		# this is the range of all the addresses BEFORE the range of HBUS
		
		mbus_range_1_base_addr = 0
		mbus_range_1_addr_width = min(self.ASGN_RANGE_BASE_ADDR).bit_length() - 1 
		mbus_range_1_end_addr = self.compute_range_end_addr(mbus_range_1_base_addr, mbus_range_1_addr_width)

		# this is the range of all the addresses AFTER the range of HBUS
		mbus_range_2_base_addr = self.get_end_addr()
		mbus_range_2_addr_width = self.ASGN_RANGE_ADDR_WIDTH[0]
		mbus_range_2_end_addr = self.compute_range_end_addr(mbus_range_2_base_addr, mbus_range_2_addr_width)

		self.logger.simply_v_warning(
			f"The address range addressable from {self.NAME} in the loopback configuration"
			f"is up until {mbus_range_2_end_addr:#010x} (excluded)"
		)

		temp_base_addresses.extend([mbus_range_1_base_addr, mbus_range_2_base_addr])
		temp_addr_widths.extend([mbus_range_1_addr_width, mbus_range_2_addr_width])
		temp_end_addresses.extend([mbus_range_1_end_addr, mbus_range_2_end_addr])

		self.RANGE_BASE_ADDR = temp_base_addresses
		self.RANGE_ADDR_WIDTH = temp_addr_widths 
		self.RANGE_END_ADDR = self.compute_range_end_addresses(self.RANGE_BASE_ADDR, self.RANGE_ADDR_WIDTH)

	def father_enable_loopback(self, child_name: str):
		self.MASTER_NAMES.append(child_name)
		self.NUM_SI += 1
	
	def add_reachability(self):
		super().add_reachability()
		for bus in self.children_busses:
			bus.add_to_reachable(self.NAME)
			#everything that can reach this node can also reach the nodes reachable from this node
			bus.add_list_to_reachable(self.REACHABLE_FROM)
			#recursion
			bus.add_reachability()

	def get_peripherals(self) -> list[Peripheral]:
		peripherals: list[Peripheral] = []
		#get all the peripherals on this bus
		peripherals.extend(super().get_peripherals())
		#recursively get peripherals of children_busses
		for bus in self.children_busses:
			peripherals.extend(bus.get_peripherals())

		return peripherals

	def print_vars(self):
		#print peripherals
		super().print_vars()
		for bus in self.children_busses:
			print(f"Printing {bus.NAME}\n")
			pprint(vars(bus))
			print("\n")
			bus.print_vars()


	
	#COMPOSITE INTERFACE IMPLEMENTATION

	def generate_children(self):
		for i, node_name in enumerate(self.RANGE_NAMES):
			if(node_name == "MBUS"):
				continue
			
			#RANGE_NAME is a bus
			if("BUS" in node_name):
				bus = self.busses_factory.create_bus(node_name, self.ADDR_RANGES, \
						self.RANGE_BASE_ADDR[i:(i+self.ADDR_RANGES)], \
						self.RANGE_ADDR_WIDTH[i:(i+self.ADDR_RANGES)], \
						self.RANGE_CLOCK_DOMAINS[i], self.ADDR_WIDTH, self)
				if(bus):
					self.children_busses.append(bus)

			#RANGE_NAME is a peripheral
			else:
				peripheral = self.peripherals_factory.create_peripheral(node_name, self.ADDR_RANGES, \
						self.RANGE_BASE_ADDR[i:(i+self.ADDR_RANGES)], \
						self.RANGE_ADDR_WIDTH[i:(i+self.ADDR_RANGES)], \
						self.RANGE_CLOCK_DOMAINS[i])
				self.children_peripherals.append(peripheral)

		#Recursively generate children
		for bus in self.children_busses:
			bus.generate_children()

	#COMPOSITE INTERFACE IMPLEMENTATION

	#generate_children is implemented in the classes that inherit from this one

	def get_busses(self) -> list[Bus]:
		busses: list[Bus] = [self]
		for bus in self.children_busses:
			busses.extend(bus.get_busses())
		return busses

	def init_clock_domains(self):
		nodes = []
		nodes.extend(self.children_peripherals)
		nodes.extend(self.children_busses)
		self.clock_domains = Clock_Domain(nodes)
		return

