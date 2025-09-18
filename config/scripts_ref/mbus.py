from bus import Bus
import pbus
import os
from utils import *
from pprint import pprint
import peripheral
import re

class MBus(Bus):
	def __init__(self, data_dict: dict, mbus_file_name: str, addr_width: int, data_width: int, range_addr_width: list, clock: int):
		self.LEGAL_PERIPHERALS: list = []
		self.PROTOCOL: str = "AXI4"
		self.ADDR_WIDTH: int = addr_width
		self.DATA_WIDTH: int = data_width
		self.RANGE_CLOCK_DOMAINS: list = []
		self.mbus_file_name = mbus_file_name

		# MBUS has a base address of 0 as a convention
		base_addr = [0]
		# MBUS has an addr ranges of 1 as a convention
		assigned_addr_ranges = 1
		
		# init Bus object
		super().__init__(data_dict, mbus_file_name, base_addr, assigned_addr_ranges, range_addr_width, clock)

		self.RANGE_CLOCK_DOMAINS = [int(x) for x in data_dict["RANGE_CLOCK_DOMAINS"].split(" ")]

		#generate children nodes
		self.generate_children()


	def generate_children(self):
		pbus_pattern = r"PBUS_\d+"   # \d+ matches one or more digits
		hbus_pattern = r"HBUS_\d+"   # \d+ matches one or more digits
		root_dir = os.path.join("/", *self.mbus_file_name.split("/")[:-1])
		
		for i, node_name in enumerate(self.RANGE_NAMES):
			match = re.search(pbus_pattern, node_name)
			if (match):
				pbus_file_name = os.path.join(root_dir, "config_" + match.group().lower() + ".csv")
				pbus_data_dict = parse_csv(pbus_file_name)

				node = pbus.PBus(pbus_data_dict, pbus_file_name, [self.RANGE_ADDR_WIDTH_LIST[i]], \
						[self.RANGE_BASE_ADDR_LIST[i]], self.ADDR_RANGES, self.RANGE_CLOCK_DOMAINS[i])
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

			node = peripheral.Peripheral(self.RANGE_NAMES[i], self.ADDR_RANGES, [self.RANGE_BASE_ADDR_LIST[i]],\
					[self.RANGE_ADDR_WIDTH_LIST[i]], self.RANGE_CLOCK_DOMAINS[i])

			pprint(vars(node))
			self.children.append(node)
