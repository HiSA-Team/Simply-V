import re
from typing import NoReturn
from addr_range import Addr_Range
from singleton import SingletonABCMeta
from logger import Logger

class Factory(metaclass=SingletonABCMeta):
	logger = Logger.get_instance()

	def __init__(self):
		pass

	#Each node (peripheral or bus) that should be created, 
	#shouldn't have duplicates, so when refering to different instances of different nodes
	#(for example TIM_1 allocated on PBUS and TIM_1 allocated on MBUS)
	#calling them with the same name in the configuration (.csv) files
	#will lead to an error in the configuration flow.
	#When trying to specify different "nodes" of the same "category"
	#you MUST adhere the following syntax "BASENAME_#" where "#" is a number.
	#In the case of absence of multiple instances with the same "BASENAME"
	#"#" can be omitted.
	#The important thing is that there aren't duplicates of the same "BASENAME"
	#anywhere in the configuration, when they're clearly refering to different
	#istances of the same "BASENAME".

	def _extract_base_name(self, name: str):
		pattern = re.compile(r"^(?P<prefix>[A-Za-z0-9]+)")
	
		match = pattern.match(name)
		if match:
			base_name = match.group("prefix")
			return base_name.upper() #upper just in case, to have uniform names
		else:
			self.logger.simply_v_crash(f"There is something wrong with {name} format name\n")

	def _extract_clock_frequency(self, clock_domain: str) -> int | NoReturn:
		try:
			return int(clock_domain.split("_")[-1])
		except ValueError:
			self.logger.simply_v_crash(f"There is something wrong with {clock_domain} format name\n")

	def _create_addr_ranges(self, base_name: str, range_name: str, base_addr: list[int], addr_width: list[int], 
							clock_domain: list[str]) -> list[Addr_Range]:

		addr_ranges_list = []
		for addr_range in range(len(base_addr)):
			clock_frequency = self._extract_clock_frequency(clock_domain[addr_range])
			addr_ranges_list.append(Addr_Range(base_name, range_name, base_addr[addr_range], addr_width[addr_range], clock_domain[addr_range], clock_frequency))
		return addr_ranges_list
