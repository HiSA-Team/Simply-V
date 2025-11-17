import os
from addr_range import Addr_Range
from env import *
from factories.factory import Factory
from parsers.nonleafbus_parser import NonLeafBus_Parser
from parsers.leafbus_parser import LeafBus_Parser
from busses.bus import Bus

class Busses_Factory(Factory):
	nonleafbus_parser = NonLeafBus_Parser.get_instance()
	leafbus_parser = LeafBus_Parser.get_instance()
	env_global = Env.get_instance()

	def __init__(self):
		pass


	def create_bus(self, range_name: str, base_addr: list[int], addr_width: list[int], clock_domain: list[str], **kwargs) -> Bus | None:
		from busses.hbus import HBus
		from busses.pbus import PBus
		from busses.mbus import MBus

		base_name = self._extract_base_name(range_name)

		addr_ranges_list = self._create_addr_ranges(base_name, range_name, base_addr, addr_width, clock_domain)

		# Assuming the bus file name is for example "config_pbus_0.csv" if range_name is "PBUS_0"
		file_name = os.path.join(self.env_global.get_conf_profile_path(), "config_" + range_name.lower() + ".csv")

		# need to add the base name to the constructed busses
		match base_name:
			case "MBUS":
				data_dict = self.nonleafbus_parser.parse_csv(file_name)
				if data_dict["PROTOCOL"] == "DISABLE":
					return None
				return MBus(data_dict, addr_ranges_list, **kwargs)
			case "PBUS":
				data_dict = self.leafbus_parser.parse_csv(file_name)
				if data_dict["PROTOCOL"] == "DISABLE":
					return None
				return PBus(data_dict, addr_ranges_list)
			case "HBUS":
				data_dict = self.nonleafbus_parser.parse_csv(file_name)
				if data_dict["PROTOCOL"] == "DISABLE":
					return None
				return HBus(data_dict, addr_ranges_list, **kwargs)
			case _:
				self.logger.simply_v_crash(f"Unsupported Bus {range_name}\n")
