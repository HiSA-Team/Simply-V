from node import Node
from logger import Logger
from utils import *

from pprint import pprint

from collections import defaultdict
import re
from abc import abstractmethod, ABC


class Bus(Node, ABC):
	def __init__(self, file_name: str, axi_addr_width: int, axi_data_width: int, \
			  asgn_addr_ranges: int, asgn_range_base_addr: list, asgn_range_addr_width: list, clock: int):

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
		self.children : list[Node] = []

		self.ADDR_RANGES : int = 1 
		self.RANGE_BASE_ADDR : list[int]
		self.RANGE_ADDR_WIDTH : list[int]
		self.RANGE_END_ADDR : list[int]	= []	# computed from RANGE_BASE_ADDR and RANGE_ADDR_WIDTH

				
		# init Node object
		super().__init__(asgn_addr_ranges, asgn_range_base_addr, asgn_range_addr_width, clock)


        # Must match a legal prefix exactly OR prefix + '_' + integer.
        # If duplicates appear, they must be numbered (TIM_0, TIM_1, ...).
	def check_peripherals(self, peripherals: list[str]):
		simply_v_crash = self.logger.simply_v_crash

		seen = defaultdict(set)  # prefix -> set of used suffixes
		pattern = re.compile(r"^(?P<prefix>[A-Za-z_]+)(?:_(?P<idx>\d+))?$")

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

	@abstractmethod
	def generate_children(self):
		return

	def compute_range_end_addr(self, base_addr: int, addr_width: int) -> int:
		return base_addr + ~(~1 << (addr_width-1))

	def compute_range_end_addresses(self, base_addresses: list[int], addr_widths: list[int]) -> list[int]: 
		end_addresses = []
		for i in range(len(base_addresses)):
			end_addresses.append(self.compute_range_end_addr(base_addresses[i], addr_widths[i]))
		return end_addresses

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

		self.RANGE_END_ADDR = self.compute_range_end_addresses(self.RANGE_BASE_ADDR, self.RANGE_ADDR_WIDTH)



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
		

		for i in range(len(self.RANGE_BASE_ADDR)):
			base_address = self.RANGE_BASE_ADDR[i]
			end_address = self.RANGE_END_ADDR[i]

			# Check if the base addr does not fall into the addr range (e.g. base_addr: 0x100 is not allowed with range_width=12)
			if (base_address & ~(~1 << (self.RANGE_ADDR_WIDTH[i]-1)) ) != 0:
				simply_v_crash(f"BASE_ADDR does not match RANGE_ADDR_WIDTH")

				# Check if the current address does not fall into the addr range one of the previous slaves
				for j in range(len(self.RANGE_BASE_ADDR)):
					# Skip yourself from the check
					if (i == j):
						continue
						
					if  ((base_address <= end_addresses[j])   and (base_address >= base_addresses[j])) or \
						((end_address >= base_addresses[j])   and (base_address <= base_addresses[j])) or \
						((base_address <= base_addresses[j])  and (end_address >= end_addresses[j])  ) or \
						((base_address >= base_addresses[j])  and (end_address <= end_addresses[j])  ):

						simply_v_crash(f"Address of {self.RANGE_NAMES[i]} overlaps with {self.RANGE_NAMES[j]}")

	def check_inter(self):
		# Check that all the RANGES are included in the Bus addresses ranges
		# the "ASGN" variables are the one assigned to the current bus
		# not the one relatives to the nodes that we're trying to "allocate"
		# on this bus
		
		bus_base_addresses = self.ASGN_RANGE_BASE_ADDR
		bus_end_addresses = self.ASGN_RANGE_END_ADDR
		#for each node connected to the bus check if it's included in at least
		#one bus address range
		for base, end in zip(self.RANGE_BASE_ADDR, self.RANGE_END_ADDR):
			included = 0
			# Check if all the Nodes attached to this bus, fit in the assigned Address range
			for bus_base, bus_end in zip(bus_base_addresses, bus_end_addresses):
				if ((base >= bus_base) and (end <= bus_end)):
					included = 1
					break

			if(included == 0):
				self.logger.simply_v_crash(f"The addresses assigned to some Node (Peripheral or Bus) in this bus "
						"don't fit in the address ranges assigned to this bus from his parent bus.")
