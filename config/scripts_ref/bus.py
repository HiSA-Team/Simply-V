from node import Node
from logger import Logger
from utils import *
from abc import abstractmethod, ABC

class Bus(Node, ABC):
	def __init__(self, data_dict: dict, file_name: str, base_addr: int, assigned_addr_ranges: int, \
				addr_width: int, clock: int):

		self.ID_WIDTH			 : int = 4		# ID Data Width for MI and SI (a subset of it is used by the Interfaces Thread IDs)
		self.NUM_MI				 : int			# Master Interface (MI) Number
		self.NUM_SI				 : int	 		# Slave Interface (SI) Number
		self.MASTER_NAMES        : list		    # List of names of masters connected to the bus
		self.RANGE_NAMES         : list		    # List of names of slaves connected to the bus
		self.children : list = []					# Initialized by MBUS
		self.logger = Logger(file_name)		# Utils object used for logging

		# Reduntant informations, the Bus just uses them to initialize the
		# children nodes after checking if they are correct
		self.ADDR_RANGES : int = 1 
		self.RANGE_BASE_ADDR_LIST : list
		self.RANGE_ADDR_WIDTH_LIST : list
		
		# init Node object
		super().__init__(assigned_addr_ranges, base_addr, addr_width, clock)

		#check params
		self.check_assign_params(data_dict)

		#check params interactions
		self.check_intra()

	@abstractmethod
	def generate_children(self):
		return

	def check_assign_params(self, data_dict: dict):
		simply_v_crash = self.logger.simply_v_crash
		
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

		self.RANGE_BASE_ADDR_LIST =[int(x, 16) for x in data_dict["RANGE_BASE_ADDR"].split(" ")] 

		if ("RANGE_ADDR_WIDTH" not in data_dict):
			simply_v_crash("RANGE_ADDR_WIDTH is mandatory")

		self.RANGE_ADDR_WIDTH_LIST = [int(x) for x in data_dict["RANGE_ADDR_WIDTH"].split(" ")]
		
		if ("ADDR_RANGES" in data_dict):
			self.ADDR_RANGES = data_dict["ADDR_RANGES"]


	def check_intra(self):
		simply_v_crash = self.logger.simply_v_crash

		if (self.NUM_MI != len(self.RANGE_NAMES)):
			simply_v_crash(f"The NUM_MI value {self.NUM_MI} does not match the number of RANGE_NAMES")

		if (self.NUM_MI != len(self.RANGE_BASE_ADDR_LIST)):
			simply_v_crash(f"The NUM_MI value {self.NUM_MI} does not match the number of RANGE_BASE_ADDR")

		if (self.NUM_MI != len(self.RANGE_ADDR_WIDTH_LIST)):
			simply_v_crash(f"The NUM_MI value {self.NUM_MI} does not match the number of RANGE_ADDR_WIDTH")

		if (self.NUM_SI != len(self.MASTER_NAMES)):
			simply_v_crash(f"The NUM_SI does not match MASTER_NAMES in {self.MASTER_NAMES}")
		
		# Check Address interactions
		base_addresses = list()
		end_addresses = list()

		for i in range(len(self.RANGE_BASE_ADDR_LIST)):
			base_address = self.RANGE_BASE_ADDR_LIST[i]
			end_address = base_address + ~(~1 << (self.RANGE_ADDR_WIDTH_LIST[i]-1))

			# Check if the base addr does not fall into the addr range (e.g. base_addr: 0x100 is not allowed with range_width=12)
			if (base_address & ~(~1 << (self.RANGE_ADDR_WIDTH_LIST[i]-1)) ) != 0:
				simply_v_crash(f"BASE_ADDR does not match RANGE_ADDR_WIDTH")

				# Check if the current address does not fall into the addr range one of the previous slaves
				for j in range(len(base_addresses)):
					if  ((base_address <= end_addresses[j])   and (base_address >= base_addresses[j])) or \
						((end_address >= base_addresses[j])   and (base_address <= base_addresses[j])) or \
						((base_address <= base_addresses[j])  and (end_address >= end_addresses[j])  ) or \
						((base_address >= base_addresses[j])  and (end_address <= end_addresses[j])  ):

						simply_v_crash(f"Address of {self.RANGE_NAMES[i]} overlaps with {self.RANGE_NAMES[j]}")

			base_addresses.append(base_address)
			end_addresses.append(end_address)

		# Check that all the RANGES are included in the Bus addresses range
		# (this is the old check_inter semantics)
		# BASE_ADDR contained in the "Node" object of this bus
		# bus_base_address = self.RANGE_BASE_ADDR
		# # RANGE_ADDR_WIDTH contained in the "Node" object of this bus
		# bus_end_address = bus_base_address + ~(~1 << (self.RANGE_ADDR_WIDTH-1))
		# # Check if all the Nodes attached to this bus, fit in the assigned Address range
		# if((min(base_addresses) < bus_base_address) or (max(end_addresses) > bus_end_address)):
		# 	simply_v_crash(f"The addresses assigned to some Node (Peripheral or Bus) in this bus\
		# 			don't fit in the address range assigned to this bus from his parent bus.")










