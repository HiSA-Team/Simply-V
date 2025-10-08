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
			asgn_addr_ranges: int, asgn_range_base_addr: list, asgn_range_addr_width: list, clock: int):

		self.LEGAL_PERIPHERALS: list[str] = ["BRAM", "DM_mem", "PBUS", "PLIC", "DDR", "HBUS"]
		self.VALID_PROTOCOLS: list[str] = ["AXI4", "DISABLE"]

		self.DDR_FREQUENCY = 300
		

		# init NonLeafBus object
		super().__init__("MBUS", mbus_file_name, axi_addr_width, axi_data_width, \
				   asgn_addr_ranges, asgn_range_base_addr, asgn_range_addr_width, clock)

		try:
			self.check_assign_params(mbus_data_dict)
		except ValueError as e:
			self.logger.simply_v_crash(f"Invalid value type: {e}")

		if(self.PROTOCOL == "DISABLE"):
			return

		self.check_intra()

		self.check_inter()

		self.check_peripherals(self.LEGAL_PERIPHERALS)

		#generate children nodes
		self.generate_children()
	
	def get_peripherals(self) -> list[Peripheral]:
		peripherals: list[Peripheral] = self.children_peripherals
		busses: list[Bus] = self.children_busses
		nonleaf_busses: list[NonLeafBus] = self.children_nonleaf_busses
		idx = 0
		while(idx < len(nonleaf_busses)):
			peripherals.extend(nonleaf_busses[idx].children_peripherals)
			nonleaf_busses.extend(nonleaf_busses[idx].children_nonleaf_busses)
			busses.extend(nonleaf_busses[idx].children_busses)
			idx += 1

		idx = 0
		while(idx < len(busses)):
			peripherals.extend(busses[idx].children_peripherals)
			idx += 1

		return peripherals 

	def check_assign_params(self, data_dict):
		super().check_assign_params(data_dict)

	def check_intra(self):
		#check params interactions of BUS object
		super().check_intra()

		simply_v_crash = self.logger.simply_v_crash
		
		if self.PROTOCOL not in self.VALID_PROTOCOLS:
			simply_v_crash(f"Unsupported protocol: {self.PROTOCOL}")


		# Check valid clock domains
		for i in range(len(self.RANGE_CLOCK_DOMAINS)):

			# UNIMPLEMENTED
			# if config.RANGE_CLOCK_DOMAINS[i] not in SUPPORTED_CLOCK_DOMAINS[SOC_CONFIG] and config.RANGE_NAMES[i] not in {"DDR", "HBUS"}:
			# 	print_error(f"The clock domain {config.RANGE_CLOCK_DOMAINS[i]}MHz is not supported")
			# 	return False
			# Check if all the main_clock_domain slaves have the same frequency as MAIN_CLOCK_DOMAIN
			self.logger.simply_v_warning("MBUS check_intra isn't fully implemented")

			# if (self.RANGE_NAMES[i] == "DDR") or (self.RANGE_NAMES[i] == "HBUS"):
			# 	if self.RANGE_CLOCK_DOMAINS[i] != self.DDR_FREQUENCY:
			# 		simply_v_crash(f"The DDR and HBUS frequency {self.RANGE_CLOCK_DOMAINS[i]} must be the same of DDR board clock {self.DDR_FREQUENCY}")
			#
			# else:
			# 	if (self.RANGE_NAMES[i] != "PBUS"):
			# 		if self.RANGE_CLOCK_DOMAINS[i] != self.CLOCK:
			# 			simply_v_crash(f"The {self.RANGE_NAMES[i]} frequency {self.RANGE_CLOCK_DOMAINS[i]} must be the same as MAIN_CLOCK_DOMAIN")

			# Check if the DDR has the right frequency

	def check_inter(self):
		super().check_inter()

	
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

				pprint(vars(node))
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
				pprint(vars(node))
				self.children_nonleaf_busses.append(node)
				continue

			node = Peripheral(self.RANGE_NAMES[i], self.ADDR_RANGES, \
						self.RANGE_BASE_ADDR[i:(i+self.ADDR_RANGES)], \
						self.RANGE_ADDR_WIDTH[i:(i+self.ADDR_RANGES)], \
						self.RANGE_CLOCK_DOMAINS[i])

			pprint(vars(node))
			self.children_peripherals.append(node)

