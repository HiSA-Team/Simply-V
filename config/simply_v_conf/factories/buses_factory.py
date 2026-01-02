# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the Factory specialization class used to create buses, 
# it uses the parsers objects to extract the buses data 
# and also manages the "PROTOCOL" = "DISABLE" used to deactivate
# buses configuration, returning "None" in case of creation of a disabled bus

from parsers.mbus_parser import MBUS_Parser
from general.addr_range import Addr_Ranges
from .factory import Factory
from parsers.nonleafbus_parser import NonLeafBus_Parser
from parsers.leafbus_parser import LeafBus_Parser
from buses.bus import Bus

class Buses_Factory(Factory):
	mbus_parser = MBUS_Parser.get_instance()
	nonleafbus_parser = NonLeafBus_Parser.get_instance()
	leafbus_parser = LeafBus_Parser.get_instance()

	# Buses Factory constructor
	def __init__(self):
		super().__init__()

	# Function used for the creation of buses, checks for duplicated buses, extracts base name from full name and
	# clock frequency from clock domain
	def create_bus(self, full_name: str, base_addr: list[int], addr_width: list[int], 
						clock_domain: str, **kwargs) -> Bus | None:

		# this can be avoided implementing the "full" factory method design
		# decoupling "Buses_Factory" from the actual concrete buses
		# but for now we keep it simpler
		from buses.hbus import HBus
		from buses.pbus import PBus
		from buses.mbus import MBus

		# register creation to check for duplicates
		self._register_creation(full_name)

		# extract informations and create "Addr_Ranges" to inject in the bus object
		base_name = self._extract_base_name(full_name)

		clock_frequency = self.extract_clock_frequency(clock_domain)
		addr_ranges = Addr_Ranges(full_name, base_addr, addr_width)

		# Assuming the bus file name is for example "config_pbus_0.csv" if full_name is "PBUS_0"
		file_name = self.env.get_config_path(full_name)

		# Create concrete bus
		match base_name:
			case "MBUS":
				data_dict = self.mbus_parser.parse_csv(file_name)
				if data_dict["PROTOCOL"] == "DISABLE":
					raise ValueError("MBUS specified with DISABLE option. (MBUS is mandatory for the configuration)")
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
