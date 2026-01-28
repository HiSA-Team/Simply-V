# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the Composite class of the "Composite" design pattern
# this implements all the functions of the "Component" (Bus) class interface.
# This class lets all future "NonLeaf" bus types (the ones that can have Peripherals and other
# buses attached to them) to just inherit from this class in order to be compatible with
# with the Bus hierarchy modeled with the "Composite" design pattern.
# This class implements the "LOOPBACK" functionality that a bus can use to address ranges
# that are attached to the "father" bus

from typing import Optional, cast
from general.node import Node
from general.addr_range import Addr_Ranges
from general.env import Env
from general.logger import Logger
from .bus import Bus
from peripherals.peripheral import Peripheral
from factories.buses_factory import Buses_Factory

class NonLeafBus(Bus):
	env = Env.get_instance()
	buses_factory = Buses_Factory.get_instance()
	logger = Logger.get_instance()
	#These params are empty because they are defined by children classes.
	#Based on the bus type a children class must initialize them with the 
	#adequate values, they're specified here so that "NonLeafBus" class can expose
	#common functions that will use them (_check_legal_buses function)
	LEGAL_BUSES = ()
	DDR4_LEGAL_CHANNELS = ()


	def __init__(self, base_name: str, data_dict: dict, assigned_addr_ranges: Addr_Ranges, axi_addr_width: int, 
				axi_data_width: int, clock_domain: str, clock_frequency: int, father: Optional["NonLeafBus"]):
		# init Bus object
		super().__init__(base_name, data_dict, assigned_addr_ranges, axi_addr_width, 
							axi_data_width, clock_domain, clock_frequency)

		self.father = father 
		self._children_buses: list[Bus] = []
		self.loopback_ranges: Addr_Ranges
		self.LOOPBACK: bool = data_dict["LOOPBACK"]
		# Set legal ddr4 channels in order to find erroneous ddr4 channels configurations
		self.peripherals_factory.set_ddr4_legal_channels(self.FULL_NAME, self.DDR4_LEGAL_CHANNELS)
		# NonLeafBuses can expose clock to their parent (this is used to generate the svinc clock configuration)
		# if the clock domain used in the configuration contains the name of the father bus
		# then this bus isn't generating a clock but it's taking a clock directly from the father

		self.IS_CLOCK_GENERATOR: bool = True
		if(father):
			self.IS_CLOCK_GENERATOR: bool = not father.FULL_NAME in clock_domain

		if (self.LOOPBACK == True):
			base_addr = self.assigned_addr_ranges.get_base_addr()

			# Force base addr to power of 2
			if(not (base_addr & (base_addr -1) == 0)):
				raise ValueError(f"Activated LOOPBACK in {self.FULL_NAME} with a BASE_ADDR"
											" that isn't a power of 2 or 0.")
	

	
	def _father_enable_loopback(self, child_name: str):
		#NonLeaf buses that have "LOOPBACK" activated will call this function
		#to modify the "father" bus informations to support the LOOPBACK
		self.MASTER_NAMES.append(child_name)
		self.NUM_SI += 1

	def _child_enable_loopback(self):
		if(not self.father):
			raise ValueError(f"Can't enable loopback on {self.FULL_NAME} without a father")

		#NonLeaf buses that have "LOOPBACK" activated will call this function
		#to modify themselves to support the LOOPBACK
		#the function assumes ADDR_RANGES == 1, this invariant is kept by the
		#"NonLeafBus_Parser" class while parsing the .csv to initialize this bus

		#To support LOOPBACK, the bus will consider the "ADDR_RANGES" variable
		#equal to 2, and add a slave interface, ADDR_RANGE is = 2 because 
		#the slave interface for the loopback will address 2 ranges, the
		#addresses BEFORE this bus and the addresses AFTER this bus

		#Two Edge Cases to keep in mind:
		#this bus is in the first range of the father (base_addr == father_base_addr)
		#this bus is in the last range of the father (end_addr == father_end_addr)
		#in each of these cases the loopback can be activated without using the "ADDR_RANGE = 2"
		#method

		father_0_base_addr = self.father.get_base_addr()
		this_base_addr = self.get_base_addr()
		# this is the range of all the addresses BEFORE the range of children nonleaf bus
		father_0_addr_width = this_base_addr.bit_length() - 1 

		# this is the range of all the addresses AFTER the range of children nonleaf bus
		this_end_addr = self.get_end_addr()
		father_1_base_addr = this_end_addr 
		# compute the number of consecutive least significant bits equal to 0
		father_1_addr_width = (father_1_base_addr & - father_1_base_addr).bit_length() - 1
		father_1_end_addr = self.father.get_end_addr()

		base_addresses = []
		addresses_widths = []

		self.NUM_MI += 1

		if((father_0_base_addr != this_base_addr) and (father_1_end_addr != this_end_addr)):
			self.ADDR_RANGES = 2
			
		if(father_0_base_addr != this_base_addr):
			base_addresses.append(father_0_base_addr)
			addresses_widths.append(father_0_addr_width)

		if(father_1_end_addr != this_end_addr):
			base_addresses.append(father_1_base_addr)
			addresses_widths.append(father_1_addr_width)

		self.loopback_ranges = Addr_Ranges(self.father.FULL_NAME, base_addresses, addresses_widths)

		# logging
		for addr_range in self.loopback_ranges:
			self.logger.simply_v_info(f"Created LOOPBACK range [{hex(addr_range.RANGE_BASE_ADDR)} " 
							          f"- { hex(addr_range.RANGE_END_ADDR - 1)}] on {self.father.FULL_NAME} "
							          f"from {self.FULL_NAME}")
	
	def _check_legal_buses(self):
		for b in self._children_buses:
			if b.BASE_NAME not in self.LEGAL_BUSES:
				raise ValueError(f"Unsupported bus {b.FULL_NAME} for this bus")

	
	# Return bus and peripherals children address ranges (taking into account LOOPBACK ranges also)
	# ordered by increasing base address
	def get_ordered_children_ranges(self) -> list[Addr_Ranges]:
		ranges: list[Addr_Ranges] = super().get_ordered_children_ranges()
		for bus in self._children_buses:
			ranges.append(bus.assigned_addr_ranges)

		if(self.LOOPBACK):
			ranges.append(self.loopback_ranges)

		# Implicitly using "__lt__" function of "Addr_Ranges"
		return sorted(ranges)


	#COMPONENT INTERFACE - COMPOSITE IMPLEMENTATION
	#Recursive part of the recursion

	def generate_children(self):
		#NonLeaf buses need to create children peripherals and buses
		peripherals_names: list[str] = []
		peripherals_bases: list[int] = []
		peripherals_widths: list[int] = []
		peripherals_clock_domains: list[str] = []

		for i, node_name in enumerate(self._RANGE_NAMES):
			bases: list[int] = self._RANGE_BASE_ADDR[i:(i+self.ADDR_RANGES)]
			widths: list[int] = self._RANGE_ADDR_WIDTH[i:(i+self.ADDR_RANGES)]
			domain: str = self._RANGE_CLOCK_DOMAINS[i]
			# Create bus
			if("BUS" in node_name):
				bus = self.buses_factory.create_bus(node_name, bases, widths, domain, \
						axi_addr_width=self.ADDR_WIDTH, father = self)
				self._children_buses.append(bus)
			# if the name doesn't contain "BUS" treat this addr_range as a peripheral
			else:
				peripherals_names.append(node_name)
				peripherals_bases += bases
				peripherals_widths += widths
				peripherals_clock_domains.append(domain)
		
		# create all the peripherals
		self._children_peripherals = self._generate_peripherals(self.ADDR_RANGES, peripherals_names, 
														 peripherals_bases, peripherals_widths, 
														 peripherals_clock_domains)
		#Recursive call on all the buses
		for bus in self._children_buses:
			bus.generate_children()

	def activate_loopback(self):
		#NonLeaf buses need to activate the loopback, we assume to call this function from a "child"
		#and activate the loopback for both child an father
		if (self.LOOPBACK):
			if(not self.father):
				raise ValueError(f"Can't enable loopback on {self.FULL_NAME} without a father")

			self.father._father_enable_loopback(self.FULL_NAME)
			self._child_enable_loopback()

		#Recursive call on all the buses in order to activate the LOOPBACK feature
		#in one pass on all the Buses that specified LOOPBACK=1 in their .csv config file.
		for bus in self._children_buses:
			bus.activate_loopback()


	def sanitize_addr_ranges(self):
		#NonLeaf buses need to sanitize addresses of both children peripherals and buses
		nodes = self.get_nodes()
		super()._sanitize_addr_ranges(nodes)

		#Recursive call on all the buses
		for bus in self._children_buses:
			bus.sanitize_addr_ranges()

	def check_legals(self):
		#NonLeaf buses need to control that both children peripherals and buses are legal
		self._check_legal_peripherals()
		self._check_legal_buses()
		#Also control that configured DDR4 channels are right

		#Recursive call on all the buses
		for bus in self._children_buses:
			bus.check_legals()

	def add_reachability(self):
		#NonLeaf buses need to modify the reachability params of their children peripherals and
		#children buses, they also need to modify the reachability of all the addr_ranges
		#reachable with the "LOOPBACK" configuration

		#add reachability of peripherals
		super()._add_peripherals_reachability()
		
		#add reachability of buses
		for bus in self._children_buses:
			for addr_range in bus.assigned_addr_ranges:
				for self_range in self.assigned_addr_ranges:
					addr_range.add_list_to_reachable(self_range.get_reachable())
					addr_range.add_to_reachable(self.FULL_NAME)

		if(self.LOOPBACK):
			if(not self.father):
				raise ValueError(f"Can't enable loopback on {self.FULL_NAME} without a father")
			#get all the peripherals and buses from the "father" bus
			#and check if this Nonleafbus can reach them

			nodes: list[Node] = []
			peripherals = self.father.get_peripherals(recursive=True)
			nodes += cast(list[Node], peripherals)

			buses: list[Bus] = [self.father]
			father_buses = self.father.get_buses(recursive=True)

			if(father_buses):
				buses.extend(father_buses)

			nodes += cast(list[Node], buses)

			#Check all the "assigned_addr_ranges" of the children nodes (Peripherals/Buses)
			#if an addr_range is included in 1 of the ranges reachable from the loopback
			#adjust their reachability
			for n in nodes:
				for addr_range in n.assigned_addr_ranges:
					if addr_range in self.loopback_ranges:
						addr_range.add_to_reachable(self.FULL_NAME)
						for self_range in self.assigned_addr_ranges:
							addr_range.add_list_to_reachable(self_range.get_reachable())
			

		#Recursive call on all the buses
		for bus in self._children_buses:
			bus.add_reachability()

	
	def get_buses(self, recursive: bool) -> list[Bus] | None:

		children_buses: list[Bus] = self._children_buses.copy() 

		if(recursive):
			#Recursive call on all the buses
			for bus in self._children_buses:
				recursive_children = bus.get_buses(recursive)
				if(recursive_children):
					children_buses.extend(recursive_children)
			
		return children_buses


	def get_peripherals(self, recursive: bool) -> list[Peripheral]:
		#NonLeaf buses need to	retrieve the peripherals attached to them +
		#all the peripherals attached to their children buses
		peripherals = self._children_peripherals.copy()

		if(recursive):
			#Recursive call on all the buses
			for bus in self._children_buses:
				peripherals.extend(bus.get_peripherals(recursive))
		
		return peripherals


	def check_clock_domains(self) -> None:
		clock_domains = set()
		clock_domains.update(self.env.get_def_clock_domains())

		children_nodes = self.get_nodes()

		# we're checking that every node on this bus that isn't generating a clock
		# is either clocked by one of the default clocks ("MBUS" ones)
		# or by other nodes that can generate clocks on this bus
		for node in children_nodes:
			if(node.IS_CLOCK_GENERATOR):
				clock_domains.add(node.CLOCK_DOMAIN)

		for node in children_nodes:
			if node.CLOCK_DOMAIN not in clock_domains:
				raise ValueError(f"Node {node.FULL_NAME} on {self.FULL_NAME}"
								 f" is clocked with a non existing clock domain ({node.CLOCK_DOMAIN})")

		# Now check that the bus itself is clocked from a default ("MBUS") or local clock domain
		if self.CLOCK_DOMAIN not in clock_domains:
			raise ValueError(f"{self.FULL_NAME} is clocked with a non existing clock domain({self.CLOCK_DOMAIN})")

		#Recursive call on all the buses
		for bus in self._children_buses:
			bus.check_clock_domains()
