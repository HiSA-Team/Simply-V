# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the base class that models the "Component" class
# in the "Composite design pattern" used to model the recursive structure of
# a bus hierarchy.
# This class declares all the functions that the "Composite" class (NonLeafBus)
# and the "Leaf" class (LeafBus) must implement to fulfill the "Composite" pattern.
# it also defines internal function (the functions starting with "_") that expose
# common logic and attributes used from both the "Composite" and "Leaf" classes

from addr_range import Addr_Range
from peripherals.peripheral import Peripheral
from factories.peripherals_factory import Peripherals_Factory
from logger import Logger
from abc import abstractmethod
from node import Node

class Bus(Node):
	#General class parameters common to all the "Bus" istances
	peripherals_factory = Peripherals_Factory.get_instance()
	logger = Logger.get_instance()

	#These params are empty because they are defined by children classes.
	#Based on the bus type a children class must initialize them with the 
	#adequate values, they're specified here so that "Bus" class can expose
	#common functions that will use them (_check_legal_peripherals function)
	LEGAL_PERIPHERALS = ()
	LEGAL_PROTOCOLS = ()

	# Bus Constructor
	def __init__(self, range_name: str, data_dict: dict, asgn_addr_ranges: list[Addr_Range], axi_addr_width: int, 
					axi_data_width: int, clock_domain: str, clock_frequency: int):

        #General configuration parameters
		self.ID_WIDTH			 : int = data_dict["ID_WIDTH"]
		self.NUM_MI				 : int = data_dict["NUM_MI"]
		self.NUM_SI				 : int = data_dict["NUM_SI"]
		self.MASTER_NAMES        : list[str] = data_dict["MASTER_NAMES"].copy()
		self.PROTOCOL			 : str = data_dict["PROTOCOL"]
        #Axi widths
		self.ADDR_WIDTH: int = axi_addr_width
		self.DATA_WIDTH: int = axi_data_width
		self.ADDR_RANGES: int = data_dict["ADDR_RANGES"].copy()
        #Children Parameters internally used only to generate the children objects
		#should never use them directly
		self._RANGE_NAMES: list[str] = data_dict["RANGE_NAMES"].copy()
		self._RANGE_BASE_ADDR: list[int] = data_dict["RANGE_BASE_ADDR"].copy()
		self._RANGE_ADDR_WIDTH: list[int] = data_dict["RANGE_ADDR_WIDTH"].copy()

		self.children_peripherals : list[Peripheral] = []

		#check on addr_width
		if any(addr_width > self.ADDR_WIDTH for addr_width in self._RANGE_ADDR_WIDTH):
			self.logger.simply_v_crash(f"a RANGE_ADDR_WIDTH is greater than {self.ADDR_WIDTH} in {self.NAME}")

		#check protocol
		if self.PROTOCOL not in self.LEGAL_PROTOCOLS:
			self.logger.simply_v_crash(f"Unsupported protocol {self.PROTOCOL} in {self.NAME}")

		#Create Node object
		super().__init__(range_name, asgn_addr_ranges, clock_domain, clock_frequency)

		#create children nodes
		self._generate_children()

	# Internal functions used from children classes to implement the "COMPOSITE INTERFACE" functions

	# Internal function used in "generate_children" implementation
	def _generate_peripherals(self, addr_ranges: int, range_names: list[str], base_addr: list[int], 
								addr_width: list[int], clock_domain) -> list[Peripheral]:
		peripherals = []
		for i in range(len(range_names)):
			peripherals.append(self.peripherals_factory.create_peripheral(range_names[i], \
						base_addr[i:(i+addr_ranges)], \
						addr_width[i:(i+addr_ranges)], \
						clock_domain))
		return peripherals


	# Internal function used in "sanitize_addr_ranges" implementation
	def _sanitize_addr_ranges(self, nodes: list[Node]):
		for node1 in nodes:
			#check that nodes address ranges dont overlap
			for node2 in nodes:
				if (node1 != node2 and node1.overlaps(node2)):
					self.logger.simply_v_crash(f"Address ranges of {node1.NAME} overlaps {node2.NAME} in {self.NAME}")

			#check that all nodes address ranges are contained
			#(using "__contains__" defined in node.py)
			if node1 not in self:
				self.logger.simply_v_crash(f"Address ranges of {node1.NAME} not fully contained in {self.NAME} address ranges")


	# Internal function used in "check_legals" implementation
	def _check_legal_peripherals(self):
		simply_v_crash = self.logger.simply_v_crash

		for p in self.children_peripherals:
			if p.BASE_NAME not in self.LEGAL_PERIPHERALS:
				simply_v_crash(f"Unsupported peripheral {p.NAME} for {self.NAME}")

	
	# Internal function used in "add_reachability" implementation
	def _add_peripherals_reachability(self):
		#get all the ranges composing this bus
		ranges_names = self.get_ranges_names()
		#get the name of all the ranges that can reach this bus
		#(all the ranges that reach this node can also reach the ranges reachable from this node)
		reachable_from = self.get_reachable_from()
		for peripheral in self.children_peripherals:
			peripheral.add_list_to_reachable(ranges_names + reachable_from)

		
	# Internal function used in "get_peripherals" implementation
	def _get_peripherals(self) -> list[Peripheral]:
		return self.children_peripherals

	# Used when printing the object 
	def __str__(self):
		children_str = ", ".join(str(child) for child in self.children_peripherals)

		return (
			f"{self.__class__.__name__}("
			f"NAME={self.NAME}, "
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

	# Function used by Busses to create childrens (both Peripherals and Busses)
	@abstractmethod
	def _generate_children(self):
		pass
	
	#COMPONENT INTERFACE
	#NonLeafBus defines the recursive part of the implementation
	#LeafBus defines the base cases of recursion of the implementation

	@abstractmethod
	def sanitize_addr_ranges(self):
		pass

	@abstractmethod
	def check_legals(self):
		pass
	
	@abstractmethod
	def add_reachability(self):
		pass

	@abstractmethod
	def check_clock_domains(self):
		pass
	
	@abstractmethod
	def get_busses(self) -> list["Bus"] | None:
		pass

	@abstractmethod
	def get_peripherals(self) ->list["Peripheral"]:
		pass
