from peripheral import Peripheral
from node import Node
from logger import Logger
from utils import *

from pprint import pprint

from collections import defaultdict
import re
from abc import abstractmethod, ABC


class Bus(Node, ABC):
	def __init__(self, name: str, file_name: str, axi_addr_width: int, axi_data_width: int, \
			  asgn_addr_ranges: int, asgn_range_base_addr: list, asgn_range_addr_width: list, clock_domain: str):

		self.ID_WIDTH			 : int = 4		# ID Data Width for MI and SI (a subset of it is used by the Interfaces Thread IDs)
		self.NUM_MI				 : int = 0			# Master Interface (MI) Number
		self.NUM_SI				 : int = 0	 		# Slave Interface (SI) Number
		self.MASTER_NAMES        : list[str]		    # List of names of masters connected to the bus
		self.RANGE_NAMES         : list[str]		    # List of names of slaves connected to the bus
		self.PROTOCOL: str
		self.ADDR_WIDTH: int = axi_addr_width
		self.DATA_WIDTH: int = axi_data_width
		self.file_name: str = file_name
		self.logger: Logger = Logger(file_name)		# Utils object used for logging

		self.ADDR_RANGES : int = 1 
		self.RANGE_BASE_ADDR : list[int]
		self.RANGE_ADDR_WIDTH : list[int]
		self.RANGE_END_ADDR : list[int]	= []	# computed from RANGE_BASE_ADDR and RANGE_ADDR_WIDTH
		self.children_peripherals : list[Peripheral] = []

				
		# init Node object
		super().__init__(name, asgn_addr_ranges, asgn_range_base_addr, asgn_range_addr_width, clock_domain)


        # Must match a legal prefix exactly OR prefix + '_' + integer.
        # If duplicates appear, they must be numbered (TIM_0, TIM_1, ...).
	def check_peripherals(self, peripherals: list[str]):
		simply_v_crash = self.logger.simply_v_crash

		seen = defaultdict(set)  # prefix -> set of used suffixes
		pattern = re.compile(r"^(?P<prefix>[A-Za-z0-9_]+?)(?:_(?P<idx>\d+))?$")

		for p in self.RANGE_NAMES:
			match = pattern.match(p)
			if not match:
				simply_v_crash(f"Unsupported peripheral {p} for this bus")
				
			prefix, idx = match.group("prefix"), match.group("idx")

			# Check if prefix is allowed
			if prefix not in peripherals:
				simply_v_crash(f"Unsupported peripheral {p} for this bus")

			# Handle duplicates: either plain prefix (idx=None) or numbered
			if idx is None:
				if "" in seen[prefix]:  # duplicate plain prefix not allowed
					simply_v_crash(f"Duplicate peripherals without tailing \"_NUM\" {p}")
				seen[prefix].add("")

			else:
				if int(idx) in seen[prefix]:  # duplicate index not allowed
					simply_v_crash(f"Duplicate \"_NUM\" in peripheral {p}")
				seen[prefix].add(int(idx))
	

	def is_enabled(self):
		return not (self.PROTOCOL == "DISABLE")
	
	
	#Set all the peripherals as reachable from this bus
	def add_reachability(self):
		for peripheral in self.children_peripherals:
			peripheral.add_to_reachable(self.NAME)
			peripheral.add_list_to_reachable(self.REACHABLE_FROM)

	def check_assign_params(self, data_dict: dict):
		simply_v_crash = self.logger.simply_v_crash

		if("PROTOCOL" not in data_dict):
			simply_v_crash("Protocol is mandatory")
			
		self.PROTOCOL = data_dict["PROTOCOL"]

		# EARLY EXIT
		if(self.PROTOCOL == "DISABLE"):
			return
		
		if ("ID_WIDTH" in data_dict):
			self.ID_WIDTH = int(data_dict["ID_WIDTH"])
			if ((self.ID_WIDTH > 32) and (self.ID_WIDTH < 4) ):
				simply_v_crash("ID_WIDTH not in [4,32] range")
		
		if ("NUM_MI" not in data_dict):
			simply_v_crash("NUM_MI is mandatory")

		self.NUM_MI = int(data_dict["NUM_MI"])

		if ((self.NUM_MI <= 0) or (self.NUM_MI > 16)):
			simply_v_crash("NUM_MI must be in range (0, 16]")

		if ("NUM_SI" not in data_dict):
			simply_v_crash("NUM_SI is mandatory")

		self.NUM_SI = int(data_dict["NUM_SI"])

		if ((self.NUM_SI <= 0) or (self.NUM_SI > 16)):
			simply_v_crash("NUM_SI must be in range (0, 16]")

		if ("MASTER_NAMES" not in data_dict):
			simply_v_crash("MASTER_NAMES is mandatory")

		self.MASTER_NAMES = list(data_dict["MASTER_NAMES"].split(" "))

		if ("RANGE_NAMES" not in data_dict):
			simply_v_crash("RANGE_NAMES is mandatory")

		self.RANGE_NAMES = list(data_dict["RANGE_NAMES"].split(" "))

		if ("RANGE_BASE_ADDR" not in data_dict):
			simply_v_crash("RANGE_BASE_ADDR is mandatory")

		self.RANGE_BASE_ADDR = [int(x, 16) for x in data_dict["RANGE_BASE_ADDR"].split()]

		if ("RANGE_ADDR_WIDTH" not in data_dict):
			simply_v_crash("RANGE_ADDR_WIDTH is mandatory")

		self.RANGE_ADDR_WIDTH = [int(x) for x in data_dict["RANGE_ADDR_WIDTH"].split(" ")]

		for range_addr in self.RANGE_ADDR_WIDTH:
			if(range_addr > 64):
				simply_v_crash(f"RANGE_ADDR_WIDTH {range_addr} greather than 64")

		if ("ADDR_RANGES" in data_dict):
			self.ADDR_RANGES = data_dict["ADDR_RANGES"]


	def check_intra(self):
		simply_v_crash = self.logger.simply_v_crash
		MIN_AXI4_ADDR_WIDTH = 12
		MIN_AXI4LITE_ADDR_WIDTH = 1

		if (self.NUM_MI != len(self.RANGE_NAMES)):
			simply_v_crash(f"The NUM_MI value {self.NUM_MI} does not match the number of RANGE_NAMES")

		if ((self.NUM_MI * self.ADDR_RANGES) != len(self.RANGE_BASE_ADDR)):
			simply_v_crash(f"The NUM_MI * ADDR_RANGES value {self.NUM_MI} does not match the number of RANGE_BASE_ADDR")

		if ((self.NUM_MI * self.ADDR_RANGES) != len(self.RANGE_ADDR_WIDTH)):
			simply_v_crash(f"The NUM_MI * ADDR_RANGES value {self.NUM_MI} does not match the number of RANGE_ADDR_WIDTH")

		if (self.NUM_SI != len(self.MASTER_NAMES)):
			simply_v_crash(f"The NUM_SI does not match MASTER_NAMES in {self.MASTER_NAMES}")

		# Check the minimum widths (AXI4 12, AXI4LITE 1)
		for addr_width in self.RANGE_ADDR_WIDTH:
			if addr_width > self.ADDR_WIDTH:
				simply_v_crash(f"RANGE_ADDR_WIDTH is greater than {self.ADDR_WIDTH}")
			if self.PROTOCOL == "AXI4" and addr_width < MIN_AXI4_ADDR_WIDTH:
				simply_v_crash(f"RANGE_ADDR_WIDTH is less than {MIN_AXI4_ADDR_WIDTH}")
			if self.PROTOCOL == "AXI4LITE" and addr_width < MIN_AXI4LITE_ADDR_WIDTH:
				simply_v_crash(f"RANGE_ADDR_WIDTH is less than {MIN_AXI4LITE_ADDR_WIDTH}")
			
		# compute end addresses after all the checks
		self.RANGE_END_ADDR = self.compute_range_end_addresses(self.RANGE_BASE_ADDR, self.RANGE_ADDR_WIDTH)

		for i in range(len(self.RANGE_BASE_ADDR)):
			base_address = self.RANGE_BASE_ADDR[i]
			end_address = self.RANGE_END_ADDR[i]

			# Check if the base addr does not fall into the addr range (e.g. base_addr: 0x100 is not allowed with range_width=12)
			if (base_address & ~(~1 << (self.RANGE_ADDR_WIDTH[i]-1)) ) != 0:
				simply_v_crash(f"BASE_ADDR [{i}] does not match RANGE_ADDR_WIDTH [{i}]")

				# Check if the current address does not fall into the addr range one of the previous slaves
			for j in range(len(self.RANGE_BASE_ADDR)):
				# Skip yourself from the check
				if (i == j):
					continue
					
				if  ((base_address < self.RANGE_END_ADDR[j])   and (base_address >= self.RANGE_BASE_ADDR[j])) or \
					((end_address > self.RANGE_BASE_ADDR[j])   and (base_address <= self.RANGE_BASE_ADDR[j])) or \
					((base_address <= self.RANGE_BASE_ADDR[j])  and (end_address >= self.RANGE_END_ADDR[j])  ) or \
					((base_address >= self.RANGE_BASE_ADDR[j])  and (end_address <= self.RANGE_END_ADDR[j])  ):

					simply_v_crash(f"Address of {self.RANGE_NAMES[i]} overlaps with {self.RANGE_NAMES[j]}")
		

	def check_inter(self):
		#for each node connected to the bus check if it's included in at least
		#one bus address range
		for base, end in zip(self.RANGE_BASE_ADDR, self.RANGE_END_ADDR):
			if (not self.contains(base, end)):
				self.logger.simply_v_crash(f"The addresses assigned to some Node (Peripheral or Bus) in this bus "
						"don't fit in the address ranges assigned to this bus from his parent bus.")

	
	def get_peripherals(self) -> list[Peripheral]:
		return self.children_peripherals


	def print_vars(self):
		for peripheral in self.children_peripherals:
			print(f"Printing {peripheral.NAME}\n")
			pprint(vars(peripheral))
			print("\n")

	
	#COMPOSITE INTERFACE
	@abstractmethod
	def generate_children(self):
		pass

	@abstractmethod
	def get_busses(self) -> list["Bus"]:
		pass
