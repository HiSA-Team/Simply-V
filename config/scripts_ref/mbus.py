from bus import Bus
from nonleafbus import NonLeafBus
from utils import *
from peripheral import Peripheral
from pprint import pprint
from pbus import PBus
from node import Node
from hbus import HBus
import re 
import os

class MBus(NonLeafBus):

	def __init__(self, mbus_data_dict: dict, mbus_file_name: str, axi_addr_width: int, axi_data_width: int, \
			asgn_addr_ranges: int, asgn_range_base_addr: list, asgn_range_addr_width: list, clock_domain: str):

		self.LEGAL_PERIPHERALS: list[str] = ["BRAM", "DM_mem", "PBUS", "PLIC", "DDR", "HBUS"]
		self.VALID_PROTOCOLS: list[str] = ["AXI4", "DISABLE"]

		# init NonLeafBus object
		super().__init__("MBUS", mbus_file_name, axi_addr_width, axi_data_width, \
				   asgn_addr_ranges, asgn_range_base_addr, asgn_range_addr_width, clock_domain)

		try:
			self.check_assign_params(mbus_data_dict)
		except ValueError as e:
			self.logger.simply_v_crash(f"Invalid value type: {e}")

		if(self.PROTOCOL == "DISABLE"):
			return

		self.check_intra()

		self.check_inter()

		self.check_peripherals(self.LEGAL_PERIPHERALS)


	def check_assign_params(self, data_dict):
		super().check_assign_params(data_dict)


	def check_intra(self):
		#check params interactions of BUS object
		super().check_intra()

		simply_v_crash = self.logger.simply_v_crash
		
		if self.PROTOCOL not in self.VALID_PROTOCOLS:
			simply_v_crash(f"Unsupported protocol: {self.PROTOCOL}")

	def check_inter(self):
		super().check_inter()

	#To be called after generating children of this node (init_clock_domains uses this node list of children)
	def check_clock_domains(self):
		simply_v_crash = self.logger.simply_v_crash
		super().init_clock_domains()
		#Add MBus custom checks
		failed_checks = []
		peripherals_to_check = ["PLIC", "BRAM", "DM_mem"]
		for p in peripherals_to_check:
			ret = self.clock_domains.is_in_domain(p, self.CLOCK_DOMAIN)
			if(not ret):
				failed_checks.append(p)

		if (len(failed_checks) != 0):
			simply_v_crash(f"-{', '.join(failed_checks)}- need to be configured with MAIN CLOCK DOMAIN ({self.CLOCK_DOMAIN})")


	def add_reachability(self):
		super().add_reachability()
		for bus in self.children_busses:
			bus.add_to_reachable(self.NAME)
			bus.add_reachability()

	def generate_children(self):
			pbus_pattern = r"PBUS(?:_\d+)?"
			hbus_pattern = r"HBUS(?:_\d+)?"

			root_dir = os.path.join("/", *self.file_name.split("/")[:-1])
			
			for i, node_name in enumerate(self.RANGE_NAMES):
				match = re.search(pbus_pattern, node_name)
				if (match):
					pbus_file_name = os.path.join(root_dir, "config_" + match.group().lower() + ".csv")
					pbus_data_dict = parse_csv(pbus_file_name)

					node = PBus(match.group(), pbus_data_dict, pbus_file_name, self.ADDR_RANGES, \
							self.RANGE_BASE_ADDR[i:(i+self.ADDR_RANGES)], \
							self.RANGE_ADDR_WIDTH[i:(i+self.ADDR_RANGES)], \
							self.RANGE_CLOCK_DOMAINS[i])

					self.children_busses.append(node)
					continue

				match = re.search(hbus_pattern, node_name)
				if (match):
					hbus_file_name = os.path.join(root_dir, "config_" + match.group().lower() + ".csv") 
					hbus_data_dict = parse_csv(hbus_file_name)
					node = HBus(match.group(), hbus_data_dict, hbus_file_name, self.ADDR_RANGES, \
							self.RANGE_BASE_ADDR[i:(i+self.ADDR_RANGES)], \
							self.RANGE_ADDR_WIDTH[i:(i+self.ADDR_RANGES)], \
							self.ADDR_WIDTH, self, self.RANGE_CLOCK_DOMAINS[i] )

					self.children_busses.append(node)
					continue

				node = Peripheral(self.RANGE_NAMES[i], self.ADDR_RANGES, \
							self.RANGE_BASE_ADDR[i:(i+self.ADDR_RANGES)], \
							self.RANGE_ADDR_WIDTH[i:(i+self.ADDR_RANGES)], \
							self.RANGE_CLOCK_DOMAINS[i])

				self.children_peripherals.append(node)

			self.add_reachability()
			self.check_clock_domains()

			#Recursively generate children
			for bus in self.children_busses:
				bus.generate_children()

