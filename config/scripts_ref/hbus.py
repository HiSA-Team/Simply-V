from nonleafbus import NonLeafBus
from peripheral import Peripheral
from pbus import PBus
from utils import *
import os
import re
from pprint import pprint

class HBus(NonLeafBus):
	def __init__(self, name: str, hbus_data_dict: dict, hbus_file_name: str, asgn_addr_ranges: int, \
			asgn_range_base_addr: list, asgn_range_addr_width: list, \
			axi_addr_width: int ,father: NonLeafBus, clock_domain: str):

		self.father = father
		self.LOOPBACK: int
		#RANGES OF FATHER WHEN ENABLING LOOPBACK
		self.LEGAL_PERIPHERALS: list[str] = ["DDR", "MBUS"]
		self.VALID_PROTOCOLS: list[str] = ["AXI4", "DISABLE"]

		axi_data_width = 512
		
		# init Bus object
		super().__init__(name, hbus_file_name, axi_addr_width, axi_data_width, \
				   asgn_addr_ranges, asgn_range_base_addr, asgn_range_addr_width, clock_domain)

		try:
			self.check_assign_params(hbus_data_dict)
		except ValueError as e:
			self.logger.simply_v_crash(f"Invalid value type: {e}")

		if(self.PROTOCOL == "DISABLE"):
			return

		self.check_intra()
			
		## always check inter before adding the loopback
		## so the checks don't break on the MBUS addresses
		self.check_inter()

		self.check_peripherals(self.LEGAL_PERIPHERALS)
	
		if (self.LOOPBACK == 1):
			self.father.father_enable_loopback()
			self.child_enable_loopback()
			self.RANGE_CLOCK_DOMAINS.append(father.CLOCK_DOMAIN)


	def check_assign_params(self, data_dict):
		super().check_assign_params(data_dict)

		if("LOOPBACK" not in data_dict):
			self.LOOPBACK = 0
		else:
			self.LOOPBACK = int(data_dict["LOOPBACK"])

	
	def check_intra(self):
		#check params interactions of BUS object
		super().check_intra()

		simply_v_crash = self.logger.simply_v_crash
		
		if self.PROTOCOL not in self.VALID_PROTOCOLS:
			simply_v_crash(f"Unsupported protocol: {self.PROTOCOL}")

		if (self.LOOPBACK == 1):
			if (self.ADDR_RANGES != 1):
				simply_v_crash(f"ADDR_RANGES must be 1 when activating LOOPBACK")

			if (self.PROTOCOL == "AXI4"):
				for width in self.RANGE_ADDR_WIDTH:
					if width <= 12:
						simply_v_crash(f"When enabling LOOPBACK all the RANGE_ADDR_WIDTH "
										"should be at least 13 when using AXI4 "
										"the HBUS uses internally this extra bit "
										"to rearrange RANGES in order to accomodate "
										"the loopback configuration")

			min_base_addr = min(self.ASGN_RANGE_BASE_ADDR)

			# Force base addr to power of 2
			if(not ((min_base_addr & (min_base_addr -1) == 0) and min_base_addr != 0)):
				self.logger.simply_v_crash("When using LOOPBACK base address must be a power of 2")

		# Check valid clock domains
		self.logger.simply_v_warning("HBUS check_intra isn't fully implemented (missing clocks checks)")
	
	def check_inter(self):
		super().check_inter()

	def add_reachability(self):
		super().add_reachability()
		# If loopback enabled this HBUS can also reach
		# the peripherals in the father bus
		if(self.LOOPBACK == 1):
			#assuming that MBUS ranges are the last 2
			father_base_addr_1 = self.RANGE_BASE_ADDR[-2]
			father_base_addr_2 = self.RANGE_BASE_ADDR[-1]
			father_end_addr_1 = self.RANGE_END_ADDR[-2]
			father_end_addr_2 = self.RANGE_END_ADDR[-1]
			peripherals = self.father.get_peripherals()
			for p in peripherals:
				if (p.is_contained(father_base_addr_1, father_end_addr_1) or
					p.is_contained(father_base_addr_2, father_end_addr_2)):
					p.add_to_reachable(self.NAME)

	def generate_children(self):
		super().generate_children()
		self.init_clock_domains()
