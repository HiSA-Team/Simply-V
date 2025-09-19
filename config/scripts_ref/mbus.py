from bus import Bus
import pbus
import os
from utils import *
from pprint import pprint
import peripheral
import re

class MBus(Bus):

	def __init__(self, mbus_data_dict: dict, mbus_file_name: str, axi_addr_width: int, axi_data_width: int, \
			asgn_addr_ranges: int, asgn_range_base_addr: list, asgn_range_addr_width: list, clock: int):

		self.LEGAL_PERIPHERALS: list = ["BRAM", "DM_mem", "PBUS", "PLIC"]
		self.PROTOCOL: str = "AXI4"
		self.ADDR_WIDTH: int = axi_addr_width
		self.DATA_WIDTH: int = axi_data_width
		self.RANGE_CLOCK_DOMAINS: list = []

		
		# init Bus object
		super().__init__(mbus_data_dict, mbus_file_name, asgn_addr_ranges, asgn_range_base_addr, \
				   asgn_range_addr_width, clock)

		self.RANGE_CLOCK_DOMAINS = [int(x) for x in mbus_data_dict["RANGE_CLOCK_DOMAINS"].split(" ")]

		self.check_intra()

		self.check_peripherals(self.LEGAL_PERIPHERALS)

		#generate children nodes
		self.generate_children()

	def check_intra(self):
		#check params interactions of BUS object
		super().check_intra()

	def generate_children(self):
		pbus_pattern = r"PBUS(?:_\d+)?"
		hbus_pattern = r"HBUS(?:_\d+)?"

		root_dir = os.path.join("/", *self.file_name.split("/")[:-1])
		
		for i, node_name in enumerate(self.RANGE_NAMES):
			match = re.search(pbus_pattern, node_name)
			if (match):
				pbus_file_name = os.path.join(root_dir, "config_" + match.group().lower() + ".csv")
				pbus_data_dict = parse_csv(pbus_file_name)

				node = pbus.PBus(pbus_data_dict, pbus_file_name, self.ADDR_RANGES, \
						self.RANGE_BASE_ADDR[i:(i+self.ADDR_RANGES)], \
						self.RANGE_ADDR_WIDTH[i:(i+self.ADDR_RANGES)], \
						self.RANGE_CLOCK_DOMAINS[i])

				pprint(vars(node))
				self.children.append(node)
				continue

		# UNIMPLEMENTED
			match = re.search(hbus_pattern, node_name)
			if (match):
				hbus_file_name = os.path.join(root_dir, match.group())
				hbus_data_dict = parse_csv(file_name)
				node = hbus.HBus(pbus_data_dict)
				pprint(vars(node))
				self.children.append(node)
				continue

			node = peripheral.Peripheral(self.RANGE_NAMES[i], self.ADDR_RANGES, \
						self.RANGE_BASE_ADDR[i:(i+self.ADDR_RANGES)], \
						self.RANGE_ADDR_WIDTH[i:(i+self.ADDR_RANGES)], \
						self.RANGE_CLOCK_DOMAINS[i])

			pprint(vars(node))
			self.children.append(node)
