# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the base class that models the "Component" class
# in the "Composite design pattern" used to model the recursive structure of
# a bus hierarchy.
# This class declares all the functions that the "Composite" class (NonLeafBus)
# and the "Leaf" class (LeafBus) must implement to fulfill the "Composite" pattern.
# it also defines internal function (the functions starting with "_") that expose
# common logic and attributes used from both the "Composite" and "Leaf" classes

from typing import cast
from factories import peripherals_factory
from general.addr_range import Addr_Ranges
from general.node import Node
from general.error import Unsupported_Value_Error, Conflict_Error
from peripherals.peripheral import Peripheral
from factories.peripherals_factory import Peripherals_Factory
from abc import abstractmethod

class Bus(Node):
	#General class parameters common to all the "Bus" istances

	#These params are empty because they are defined by children classes.
	#Based on the bus type a children class must initialize them with the 
	#adequate values, they're specified here so that "Bus" class can expose
	#common functions that will use them (_check_legal_peripherals function)
	LEGAL_PERIPHERALS = ()
	LEGAL_PROTOCOLS = ()

	# Bus Constructor
	def __init__(self, base_name: str, data_dict: dict, assigned_addr_ranges: Addr_Ranges, axi_addr_width: int, 
					axi_data_width: int, clock_domain: str, clock_frequency: int):
		#Create Node object
		super().__init__(base_name, assigned_addr_ranges, clock_domain, clock_frequency)
		self.peripherals_factory = Peripherals_Factory.get_instance()

        #General configuration parameters
		self.ID_WIDTH			 : int = data_dict["ID_WIDTH"]
		self.NUM_MI				 : int = len(data_dict["RANGE_NAMES"])
		self.NUM_SI				 : int = len(data_dict["MASTER_NAMES"])
		self.MASTER_NAMES        : list[str] = data_dict["MASTER_NAMES"].copy()
		self.PROTOCOL			 : str = data_dict["PROTOCOL"]
        #Axi widths
		self.ADDR_WIDTH: int = axi_addr_width
		self.DATA_WIDTH: int = axi_data_width
		#The number of ranges associated to each children node
		self.ADDR_RANGES: int = data_dict["ADDR_RANGES"]
        #Children Parameters internally used only to generate the children objects
		#should never use them directly, after creating the new nodes, just refer to them to get
		#ranges and clocks values
		self._RANGE_NAMES: list[str] = data_dict["RANGE_NAMES"].copy()
		self._RANGE_BASE_ADDR: list[int] = data_dict["RANGE_BASE_ADDR"].copy()
		self._RANGE_ADDR_WIDTH: list[int] = data_dict["RANGE_ADDR_WIDTH"].copy()
		#As default each bus just propagates its clock domain to its children
		#MBUS is special since redefines this according to the values specified in its .csv
		self._RANGE_CLOCK_DOMAINS: list[str] = [self.CLOCK_DOMAIN] * len(self._RANGE_NAMES)

		#List of children peripherals generated in "generate_children"
		self._children_peripherals : list[Peripheral] = []

		#TODO: check if this is redundant
		#check on addr_width
		if any(addr_width > self.ADDR_WIDTH for addr_width in self._RANGE_ADDR_WIDTH):
			raise ValueError(
				f"Invalid RANGE_ADDR_WIDTH: exceeds ADDR_WIDTH={self.ADDR_WIDTH} in {self.FULL_NAME}"
			)

		#check protocol
		if self.PROTOCOL not in self.LEGAL_PROTOCOLS:
			raise Unsupported_Value_Error("PROTOCOL", self.PROTOCOL, self.LEGAL_PROTOCOLS, f"for {self.FULL_NAME}")


	# functions used from children classes to implement the "COMPOSITE INTERFACE" functions

	# PRIVATE, used in "generate_children" implementation
	def _generate_peripherals(self, addr_ranges: int, range_names: list[str], base_addr: list[int], 
						   addr_width: list[int], clock_domain: list[str]) -> list[Peripheral]:
		peripherals = []
		for i in range(len(range_names)):
			start_pos = i * addr_ranges
			p = self.peripherals_factory.create_peripheral(range_names[i], \
						base_addr[start_pos:(start_pos+addr_ranges)], \
						addr_width[start_pos:(start_pos+addr_ranges)], \
						clock_domain[i],
						self.FULL_NAME)
			peripherals.append(p)

		return peripherals


	# PRIVATE, used in "sanitize_addr_ranges" implementation
	def _sanitize_addr_ranges(self, nodes: list[Node]) -> None:
		for node1 in nodes:
			#check that nodes address ranges dont overlap
			for node2 in nodes:
				if (node1 != node2 and node1.assigned_addr_ranges.overlaps(node2.assigned_addr_ranges)):
					raise Conflict_Error("ADDR_RANGE", "ADDR_RANGE",
									f"{node1.FULL_NAME} overlaps with {node2.FULL_NAME} in {self.FULL_NAME}")

			#check that all nodes address ranges are contained
			#(using "__contains__" defined in addr_range.py)
			for addr_range in node1.assigned_addr_ranges:
				if addr_range not in self.assigned_addr_ranges:
					raise Conflict_Error("ADDR_RANGE", "ADDR_RANGE",
										f"{node1.FULL_NAME} is not "
										f"fully contained in {self.FULL_NAME}"
										)


	# PRIVATE, used in "check_legals" implementation
	def _check_legal_peripherals(self) -> None:
		for p in self._children_peripherals:
			if p.BASE_NAME not in self.LEGAL_PERIPHERALS:
				raise Unsupported_Value_Error("FULL_NAME", p.FULL_NAME, self.LEGAL_PERIPHERALS, f"for {self.FULL_NAME}")
	
	# PRIVATE, used in "add_reachability" implementation
	# iterate over each "children_peripheral" addr range, and
	# if they are contained in at least 1 Bus addr range, then add
	# reachability values to them
	def _add_reachability(self, nodes: list[Node]) -> None:
		# get the reachability values associated to each bus address range
		reaching_buses = self.assigned_addr_ranges.get_reachable_from(explicit=False)
		# buses that can reach all the address ranges of this bus
		if(self.FULL_NAME not in reaching_buses):
			common = self.assigned_addr_ranges.get_common_reachable_from()
		else:
			common = reaching_buses[self.FULL_NAME]

		for node in nodes:
			range_granularity = False
			# this is the case in which all the ranges of the bus have the same reachables
			# add to the each peripheral address range, the bus name and
			# the buses that can already reach the bus address range
			# in which the peripheral address range is contained
			for addr_range in node.assigned_addr_ranges:
				addr_range.add_list_to_reachable(common)
				for self_range in self.assigned_addr_ranges:
					if addr_range in self_range:
						addr_range.add_to_reachable(self_range.RANGE_NAME)
						range_granularity = True
				if (not range_granularity):
					addr_range.add_to_reachable(self.FULL_NAME)
				


	# Return children peripherals address ranges ordered by increasing base address
	def get_ordered_children_ranges(self) -> list[Addr_Ranges]:
		ranges: list[Addr_Ranges] = []
		for p in self._children_peripherals:
			ranges.append(p.assigned_addr_ranges)
		# Implicitly using "__lt__" function of "Addr_Ranges"
		return sorted(ranges)

	# Used when printing the object 
	def __str__(self) -> str:
		children_str = ", ".join(str(child) for child in self._children_peripherals)

		return (
			f"{self.__class__.__name__}("
			f"NAME={self.BASE_NAME}, "
			f"ID_WIDTH={self.ID_WIDTH}, "
			f"NUM_MI={self.NUM_MI}, "
			f"NUM_SI={self.NUM_SI}, "
			f"ADDR_RANGES={self.ADDR_RANGES}, "
			f"MASTER_NAMES={self.MASTER_NAMES}, "
			f"PROTOCOL={self.PROTOCOL}, "
			f"ADDR_WIDTH={self.ADDR_WIDTH}, "
			f"DATA_WIDTH={self.DATA_WIDTH}, "
			f"clock_domain={self.CLOCK_DOMAIN}, "
			f"clock_frequency={self.CLOCK_FREQUENCY}, "
			f"children={children_str}"
			f")"
		)
	
	# Returns all nodes attached to a bus
	def get_nodes(self) -> list[Node]:
		children_nodes = cast(list[Node], self.get_buses(recursive=False))
		children_nodes += cast(list[Node], self.get_peripherals(recursive=False))
		return children_nodes


	#COMPONENT INTERFACE
	#NonLeafBus defines the recursive part of the implementation
	#LeafBus defines the base cases of recursion of the implementation
	@abstractmethod
	def generate_children(self) -> None:
		pass

	@abstractmethod
	def sanitize_addr_ranges(self) -> None: 
		pass

	@abstractmethod
	def check_legals(self) -> None:
		pass

	@abstractmethod
	def activate_loopback(self) -> None:
		pass
	
	@abstractmethod
	def add_reachability(self) -> None:
		pass

	@abstractmethod
	def check_clock_domains(self) -> None:
		pass
	
	# if the "recursive" parameter is True, the function returns all the buses that the "self" bus can reach
	# if the "recursive" parameter is False, the function returns only the buses directly attached to the "self" bus
	@abstractmethod
	def get_buses(self, recursive: bool) -> list["Bus"] | None:
		pass

	# if the "recursive" parameter is True, the function returns all the peripherals that the "self" bus can reach
	# if the "recursive" parameter is False, the function returns only the peripherals directly attached to the "self" bus
	@abstractmethod
	def get_peripherals(self, recursive: bool) -> list["Peripheral"]:
		pass
