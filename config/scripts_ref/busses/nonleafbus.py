# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the Composite class of the "Composite" design pattern
# this implements all the functions of the "Component" (Bus) class interface.
# This class lets all future "NonLeaf" bus types (the ones that can have Peripherals and other
# busses attached to them) to just inherit from this class in order to be compatible with
# with the Bus hierarchy modeled with the "Composite" design pattern.
# This class implements the "LOOPBACK" functionality that a bus can use to address ranges
# that are attached to the "father" bus

from typing import Optional, cast
from node import Node
from busses.bus import Bus
from clock_domain import Clock_Domain
from addr_range import Addr_Range
from peripherals.peripheral import Peripheral
from factories.busses_factory import Busses_Factory

class NonLeafBus(Bus):
	busses_factory = Busses_Factory.get_instance()
	#These params are empty because they are defined by children classes.
	#Based on the bus type a children class must initialize them with the 
	#adequate values, they're specified here so that "NonLeafBus" class can expose
	#common functions that will use them (_check_legal_busses function)
	LEGAL_BUSSES = ()

	def __init__(self, range_name: str, data_dict: dict, asgn_addr_range: list[Addr_Range], axi_addr_width: int, 
				axi_data_width: int, clock_domain: str, clock_frequency: int, father: "NonLeafBus"):

		self.father = father 
		self.children_busses: list[Bus] = []
		self.clock_domains: Clock_Domain
		self.loopback_ranges: list[Addr_Range] = []
		self.LOOPBACK:bool = data_dict["LOOPBACK"]
		self._RANGE_CLOCK_DOMAINS: list[int] = data_dict["RANGE_CLOCK_DOMAINS"].copy()

		# init Bus object
		super().__init__(range_name, data_dict, asgn_addr_range, axi_addr_width, axi_data_width, clock_domain, clock_frequency)

		# It's important to call these functions only AFTER constructing the "super" "Bus" object
		# because they internally use children_busses and children_peripherals, initialized
		# with "_generate_children" in the "Bus" constructor
		self._activate_loopback()
		self._init_clock_domains()
	
	def _activate_loopback(self):
		#NonLeaf busses need to activate the loopback, we assume to call this function from a "child"
		#and activate the loopback for both child an father
		if (self.LOOPBACK):
			self.father._father_enable_loopback(self.NAME)
			self._child_enable_loopback()
	
	def _father_enable_loopback(self, child_name: str):
		#NonLeaf busses that have "LOOPBACK" activated will call this function
		#to modify the "father" bus informations to support the LOOPBACK
		self.MASTER_NAMES.append(child_name)
		self.NUM_SI += 1

	def _child_enable_loopback(self):
		#NonLeaf busses that have "LOOPBACK" activated will call this function
		#to modify themselves to support the LOOPBACK
		#the function assumes ADDR_RANGES == 1, this invariant is kept by the
		#"NonLeafBus_Parser" class while parsing the .csv to initialize this bus

		#To support LOOPBACK, the bus will consider the "ADDR_RANGES" variable
		#equal to 2, and add a slave interface, ADDR_RANGE is = 2 because 
		#the slave interface for the loopback will address 2 ranges, the
		#addresses BEFORE this bus and the addresses AFTER this bus
		self.ADDR_RANGES = 2
		self.NUM_MI += 1

		# split all the addr ranges to respect "ADDR_RANGES = 2" 
		for peripheral in self.children_peripherals:
			peripheral.split_addr_ranges()

		for bus in self.children_busses:
			bus.split_addr_ranges()

		# this is the range of all the addresses BEFORE the range of children nonleaf bus
		father_0_base_addr = self.father.get_base_addr()
		father_0_addr_width = self.get_base_addr().bit_length() - 1 

		# this is the range of all the addresses AFTER the range of children nonleaf bus
		father_1_base_addr = self.get_end_addr()
		# compute the number of consecutive least significant bits equal to 0
		father_1_addr_width = (father_1_base_addr & - father_1_base_addr).bit_length() - 1

		base_addresses = [father_0_base_addr, father_1_base_addr]
		addresses_widths = [father_0_addr_width, father_1_addr_width]

		ranges = self.busses_factory.create_addr_ranges(self.father.BASE_NAME, self.father.NAME, base_addresses, addresses_widths)

		self.loopback_ranges.extend(ranges)

		self.logger.simply_v_warning(
			f"The address range addressable from {self.NAME} in the loopback configuration"
			f"is up until {ranges[1].RANGE_END_ADDR} (excluded)"
		)

	
	def _check_legal_busses(self):
		simply_v_crash = self.logger.simply_v_crash

		for b in self.children_busses:
			if b.BASE_NAME not in self.LEGAL_BUSSES:
				simply_v_crash(f"Unsupported bus {b.NAME} for this bus")

	
		
	def _init_clock_domains(self):
		nodes = []
		nodes.extend(self.children_peripherals)
		nodes.extend(self.children_busses)
		self.clock_domains = Clock_Domain(nodes)
		return

	def _generate_children(self):
		#NonLeaf busses need to create children peripherals and busses
		peripherals_names = []
		peripherals_bases = []
		peripherals_widths = []
		peripherals_clock_domains = []

		for i, node_name in enumerate(self._RANGE_NAMES):
			bases = self._RANGE_BASE_ADDR[i:(i+self._ADDR_RANGES)]
			widths = self._RANGE_ADDR_WIDTH[i:(i+self._ADDR_RANGES)]
			domains = self._RANGE_CLOCK_DOMAINS[i]
			# Create bus
			if("BUS" in node_name):
				bus = self.busses_factory.create_bus(node_name, bases, widths, domains, \
						axi_addr_width=self.ADDR_WIDTH, father = self)
				# "create_bus" can return "None" if the bus is deactivated
				if(bus):
					self.children_busses.append(bus)
			# if the name doesn't contain "BUS" treat this addr_range as a peripheral
			else:
				peripherals_names.append(node_name)
				peripherals_bases.append(bases)
				peripherals_widths.append(widths)
				peripherals_clock_domains.append(domains)
		
		# create all the peripherals
		self.children_peripherals = self._generate_peripherals(self._ADDR_RANGES, peripherals_names, 
														 peripherals_bases, peripherals_widths, 
														 peripherals_clock_domains)


	#COMPONENT INTERFACE - COMPOSITE IMPLEMENTATION
	#Recursive part of the recursion

	def sanitize_addr_ranges(self):
		#NonLeaf busses need to sanitize addresses of both children peripherals and busses
		nodes: list[Node] = cast(list[Node], self.children_peripherals + self.children_busses)
		super()._sanitize_addr_ranges(nodes)

		#Recursive call on all the busses
		for bus in self.children_busses:
			bus.sanitize_addr_ranges()

	def check_legals(self):
		#NonLeaf busses need to control that both children peripherals and busses are legal
		self._check_legal_peripherals()
		self._check_legal_busses()

		#Recursive call on all the busses
		for bus in self.children_busses:
			bus.check_legals()

	def add_reachability(self):
		#NonLeaf busses need to modify the reachability params of their children peripherals and
		#children busses, they also need to modify the reachability of all the addr_ranges
		#reachable with the "LOOPBACK" configuration

		#add reachability of peripherals
		super()._add_peripherals_reachability()
		#get all the ranges composing this bus 
		ranges_names = self.get_ranges_names()
		#get the name of all the ranges that can reach this bus
		#(all the ranges that reach this node can also reach the ranges reachable from this node)
		reachable_from = self.get_reachable_from()
		
		#add reachability of busses
		for bus in self.children_busses:
			bus.add_list_to_reachable(ranges_names + reachable_from)

		if(self.LOOPBACK):
			#get all the peripherals and busses from the "father" bus
			#and check if this Nonleafbus can reach them

			nodes: list[Node] = []
			peripherals = self.father.get_peripherals()
			nodes += cast(list[Node], peripherals)

			busses = self.father.get_busses()
			if(busses):
				nodes += cast(list[Node], busses)

			#Check all the "addr_ranges" of the children nodes (Peripherals/Busses)
			#if an addr_range is included in 1 of the ranges reachable from the loopback
			#adjust their reachability
			for n in nodes:
				for addr_range in n.asgn_addr_ranges:
					if (addr_range in self.loopback_ranges[0]) or (addr_range in self.loopback_ranges[1]):
						n.add_list_to_reachable(ranges_names + reachable_from)

			
		#Recursive call on all the busses
		for bus in self.children_busses:
			bus.add_reachability()

	@abstractmethod
	def check_clock_domains(self):
		pass
	
	def get_busses(self) -> list["Bus"] | None:
		#NonLeaf busses need to	retrieve the busses attached to them +
		#all the busses attached to their children busses if any

		children_busses = self.children_busses

		#Recursive call on all the busses
		for bus in self.children_busses:
			recursion_busses = bus.get_busses()
			# check if they are != from "None" (Busses of type LeafBus will return None)
			if(recursion_busses):
				children_busses.extend(recursion_busses)
		
		return children_busses


	def get_peripherals(self) ->list["Peripheral"]:
		#NonLeaf busses need to	retrieve the peripherals attached to them +
		#all the peripherals attached to their children busses
		peripherals = self.children_peripherals

		#Recursive call on all the busses
		for bus in self.children_busses:
			peripherals.extend(bus.get_peripherals())

		return peripherals
