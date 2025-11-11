import os
from utils import parse_csv
from env import *
from logger import Logger
from factory import Factory
from busses.bus import Bus


class Busses_Factory(Factory):

	def __init__(self, logger: Logger):
		super().__init__(logger)

	def create_bus(self,  range_name: str, \
						  addr_ranges: int, \
						  range_base_addr: list[int], \
						  range_addr_width: list[int], \
						  range_clock_domain: str, *args) -> Bus:

		from busses.hbus import HBus
		from busses.pbus import PBus

		base_name = self.extract_base_name(range_name)
		# Assuming the bus file name is for example "config_pbus_0.csv" if range_name is "PBUS_0"
		env_global = Env.get_instance()
		file_name = os.path.join(env_global.get_conf_profile_path(), "config_" + range_name.lower() + ".csv")
		data_dict = parse_csv(file_name)

		# need to add the base name to the constructed busses
		match base_name:
			case "PBUS":
				return PBus(range_name, base_name, data_dict, file_name, addr_ranges, range_base_addr, range_addr_width, range_clock_domain)
			case "HBUS":
				print(*args)
				return HBus(range_name, base_name, data_dict, file_name, addr_ranges, range_base_addr, range_addr_width, range_clock_domain, *args)
			case _:
				self.logger.simply_v_crash(f"Unsupported Bus {range_name}\n")
