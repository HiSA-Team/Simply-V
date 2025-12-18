# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the base class that models the "Component" class
# in the "Composite design pattern" used to model the recursive structure of
# a bus hierarchy.
# This class declares all the functions that the "Composite" class (NonLeafBus)
# and the "Leaf" class (LeafBus) must implement to fulfill the "Composite" pattern.
# it also defines internal function (the functions starting with "_") that expose
# common logic and attributes used from both the "Composite" and "Leaf" classes

from typing import Callable
from general.addr_range import Addr_Ranges
from general.node import Node
from peripherals.peripheral import Peripheral
from factories.peripherals_factory import Peripherals_Factory
from abc import abstractmethod

class Bus(Node):
	#General class parameters common to all the "Bus" istances
	peripherals_factory = Peripherals_Factory.get_instance()

	#These params are empty because they are defined by children classes.
	#Based on the bus type a children class must initialize them with the 
	#adequate values, they're specified here so that "Bus" class can expose
	#common functions that will use them (_check_legal_peripherals function)
	LEGAL_PERIPHERALS = ()
	LEGAL_PROTOCOLS = ()

	# Bus Constructor
	def __init__(self, base_name: str, data_dict: dict, asgn_addr_ranges: Addr_Ranges, axi_addr_width: int, 
					axi_data_width: int, clock_domain: str, clock_frequency: int):
		#Create Node object
		super().__init__(base_name, asgn_addr_ranges, clock_domain, clock_frequency)

        #General configuration parameters
		self.ID_WIDTH			 : int = data_dict["ID_WIDTH"]
		self.NUM_MI				 : int = data_dict["NUM_MI"]
		self.NUM_SI				 : int = data_dict["NUM_SI"]
		self.MASTER_NAMES        : list[str] = data_dict["MASTER_NAMES"].copy()
		self.PROTOCOL			 : str = data_dict["PROTOCOL"]
        #Axi widths
		self.ADDR_WIDTH: int = axi_addr_width
		self.DATA_WIDTH: int = axi_data_width
		#The number of ranges associated to each children node
		self.CHILDREN_NUM_RANGES: int = data_dict["ADDR_RANGES"]
        #Children Parameters internally used only to generate the children objects
		#should never use them directly
		self._RANGE_NAMES: list[str] = data_dict["RANGE_NAMES"].copy()
		self._RANGE_BASE_ADDR: list[int] = data_dict["RANGE_BASE_ADDR"].copy()
		self._RANGE_ADDR_WIDTH: list[int] = data_dict["RANGE_ADDR_WIDTH"].copy()
		#List of children peripherals generated in "generate_children"
		self._children_peripherals : list[Peripheral] = []

		#check on addr_width
		if any(addr_width > self.ADDR_WIDTH for addr_width in self._RANGE_ADDR_WIDTH):
			raise ValueError(
				f"Invalid RANGE_ADDR_WIDTH: exceeds ADDR_WIDTH={self.ADDR_WIDTH} in {self.FULL_NAME}"
			)

		#check protocol
		if self.PROTOCOL not in self.LEGAL_PROTOCOLS:
			raise ValueError(
				f"Unsupported protocol '{self.PROTOCOL}' in {self.FULL_NAME}"
			)

		#create children nodes
		self._generate_children()

	# Internal functions used from children classes to implement the "COMPOSITE INTERFACE" functions

	# Internal function used in "generate_children" implementation
	def _generate_peripherals(self, addr_ranges: int, range_names: list[str], base_addr: list[int], 
						   addr_width: list[int], clock_domain: list[str]) -> list[Peripheral]:
		peripherals = []
		for i in range(len(range_names)):
			p = self.peripherals_factory.create_peripheral(range_names[i], \
						base_addr[i:(i+addr_ranges)], \
						addr_width[i:(i+addr_ranges)], \
						clock_domain[i])
			peripherals.append(p)

		return peripherals


	# Internal function used in "sanitize_addr_ranges" implementation
	def _sanitize_addr_ranges(self, nodes: list[Node]) -> None:
		for node1 in nodes:
			#check that nodes address ranges dont overlap
			for node2 in nodes:
				if (node1 != node2 and node1.asgn_addr_ranges.overlaps(node2.asgn_addr_ranges)):
					raise ValueError(
						f"Address ranges of {node1.FULL_NAME} overlap with {node2.FULL_NAME} in {self.FULL_NAME}"
					)

			#check that all nodes address ranges are contained
			#(using "__contains__" defined in addr_range.py)
			for addr_range in node1.asgn_addr_ranges:
				if addr_range not in self.asgn_addr_ranges:
					raise ValueError(
						f"Address ranges of {node1.FULL_NAME} are not fully contained in {self.FULL_NAME} address ranges"
					)


	# Internal function used in "check_legals" implementation
	def _check_legal_peripherals(self) -> None:
		for p in self._children_peripherals:
			if p.BASE_NAME not in self.LEGAL_PERIPHERALS:
				raise ValueError(
						f"Unsupported peripheral {p.FULL_NAME} for {self.FULL_NAME}"
				)
	
	# Internal function used in "add_reachability" implementation
	# iterate over each "children_peripheral" addr range, and
	# if they are contained in at least 1 Bus addr range, then add
	# reachability values to them
	def _add_peripherals_reachability(self) -> None:
		for peripheral in self._children_peripherals:
			for addr_range in peripheral.asgn_addr_ranges:
				for self_range in self.asgn_addr_ranges:
					if addr_range in self_range:
						# add bus name
						addr_range.add_to_reachable(self.FULL_NAME)
						# add the nodes that can reach the bus
						addr_range.add_list_to_reachable(self_range.get_reachable())
						break

		
	# Internal function used in "get_peripherals" implementation
	def _get_peripherals(self) -> list[Peripheral]:
		return self._children_peripherals

	# Function used to return children address ranges (of peripherals/buses) keeping an invariant
	# of "order by base address" in this way configuration functions assume the same ordering
	# of ranges for each "children" of a particular bus
	def get_ordered_children_ranges(self) -> list[Addr_Ranges]:
		# Implicitly using "__lt__" function of "Addr_Ranges"
		ranges: list[Addr_Ranges] = []
		for p in self._children_peripherals:
			ranges.append(p.asgn_addr_ranges)
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
			f"MASTER_NAMES={self.MASTER_NAMES}, "
			f"PROTOCOL={self.PROTOCOL}, "
			f"ADDR_WIDTH={self.ADDR_WIDTH}, "
			f"DATA_WIDTH={self.DATA_WIDTH}, "
			f"clock_domain={self.CLOCK_DOMAIN}, "
			f"clock_frequency={self.CLOCK_FREQUENCY}, "
			f"children={children_str}"
			f")"
		)

	# Function used by Buses to create childrens (both Peripherals and Buses)
	@abstractmethod
	def _generate_children(self) -> None:
		pass
	
	#COMPONENT INTERFACE
	#NonLeafBus defines the recursive part of the implementation
	#LeafBus defines the base cases of recursion of the implementation

	@abstractmethod
	def sanitize_addr_ranges(self) -> None:
		pass

	@abstractmethod
	def check_legals(self) -> None:
		pass
	
	@abstractmethod
	def add_reachability(self) -> None:
		pass

	@abstractmethod
	def check_clock_domains(self, custom_clocks_checks: Callable[[], None]) -> None:
		pass
	
	@abstractmethod
	def get_buses(self, recursive: bool) -> list["Bus"] | None:
		pass

	@abstractmethod
	def get_peripherals(self, recursive: bool) -> list["Peripheral"]:
		pass
