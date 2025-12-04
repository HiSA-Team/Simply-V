# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the Factory specialization class used to create busses, 
# it uses the parsers objects to extract the busses data 
# and also manages the "PROTOCOL" = "DISABLE" used to deactivate
# busses configuration, returning "None" in case of creation of a disabled bus

from general.addr_range import Addr_Ranges
from .factory import Factory
from parsers.nonleafbus_parser import NonLeafBus_Parser
from parsers.leafbus_parser import LeafBus_Parser
from busses.bus import Bus

class Busses_Factory(Factory):
	nonleafbus_parser = NonLeafBus_Parser.get_instance()
	leafbus_parser = LeafBus_Parser.get_instance()

	# Busses Factory constructor
	def __init__(self):
		super().__init__()

	# Function used for the creation of busses, checks for duplicated busses, extracts base name from full name and
	# clock frequency from clock domain
	def create_bus(self, full_name: str, base_addr: list[int], addr_width: list[int], 
						clock_domain: str, **kwargs) -> Bus | None:

		# this can be avoided implementing the "full" factory method design
		# decoupling "Busses_Factory" from the actual concrete busses
		# but for now we keep it simpler
		from busses.hbus import HBus
		from busses.pbus import PBus
		from busses.mbus import MBus

		# register creation to check for duplicates
		self._register_creation(full_name)

		# extract informations and create "Addr_Ranges" to inject in the bus object
		base_name = self._extract_base_name(full_name)
		clock_frequency = self._extract_clock_frequency(clock_domain)
		addr_ranges = Addr_Ranges(full_name, base_addr, addr_width)

		# Assuming the bus file name is for example "config_pbus_0.csv" if full_name is "PBUS_0"
		file_name = self.env.get_config_path(full_name)

		# Create concrete bus
		match base_name:
			case "MBUS":
				data_dict = self.nonleafbus_parser.parse_csv(file_name)
				if data_dict["PROTOCOL"] == "DISABLE":
					return None
				return MBus(base_name, data_dict, addr_ranges, clock_domain, clock_frequency, **kwargs)
			case "PBUS":
				data_dict = self.leafbus_parser.parse_csv(file_name)
				if data_dict["PROTOCOL"] == "DISABLE":
					return None
				return PBus(base_name, data_dict, addr_ranges, clock_domain, clock_frequency)
			case "HBUS":
				data_dict = self.nonleafbus_parser.parse_csv(file_name)
				if data_dict["PROTOCOL"] == "DISABLE":
					return None
				return HBus(base_name, data_dict, addr_ranges, clock_domain, clock_frequency, **kwargs)
			case _:
				raise ValueError(f"Unsupported Bus {full_name}\n")
