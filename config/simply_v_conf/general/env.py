# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This class contains all the "settings.sh" related configurations
# that can impact how the configuration flow behaves.
# The function implementations are full of switch cases to keep it simple,
# in future if the Env class will become more involved a hierarchy of classes
# could be designed to better manage the complexity


import os

from general.error import Unsupported_Value_Error
from .singleton import Singleton

class Env(metaclass=Singleton):
	# init Env
	def __init__(self):
		self.SUPPORTED_PROFILES = ["hpc", "embedded"]
		self.SUPPORTED_BOARDS = ["Nexys-A7-100T-Master", "Nexys-A7-50T-Master", "au250", "au280", "au50"]
		# Private variables never touch them, use the getters
		self.bus_input_files: dict[str, str]
		self._board = os.environ["BOARD"]
		# SoC Profile
		self._SIMPLYV_PROFILE = os.environ["SIMPLYV_PROFILE"]

		if (self._board not in self.SUPPORTED_BOARDS):
			raise Unsupported_Value_Error("BOARD", self._board, self.SUPPORTED_BOARDS, 
													"Probably settings.sh script wasn't sourced")


		if(self._SIMPLYV_PROFILE not in self.SUPPORTED_PROFILES):
			raise Unsupported_Value_Error("SIMPLYV_PROFILE", self._SIMPLYV_PROFILE, self.SUPPORTED_PROFILES, 
								  "Probably settings.sh script wasn't sourced")


			
	def set_inputs(self, bus_input_files: dict[str,str]):
		self.bus_input_files = bus_input_files

	def get_config_path(self, bus_name: str) -> str:
		return self.bus_input_files[bus_name]

	def get_simply_v_profile(self):
		return self._SIMPLYV_PROFILE

	def get_board(self):
		return self._board

	def get_bus_path(self, full_name: str) -> str:
		return self.bus_input_files[full_name]

	# these can be refactored in future if needed
	# like extending "Env" in a hierarchy with more specialized
	# child classes, but for now we keep it simpler
	def get_supp_ddr_chs(self) -> list[int] | None:
		match self._board:
			case "au250":
				return [0,1,2,3]
			case "au280":
				return [0,1,2]
			case "au50":
				return [0,1]
			case "Nexys-A7-100T-Master" | "Nexys-A7-50T-Master":
				return [0]
			case _:
				assert False, f"BOARD CONFIGURATION CHANGED DURING EXECUTION: {self._board}"
				

	def get_supp_hbm(self) -> bool | None:
		match self._board:
			case "Nexys-A7-100T-Master" | "Nexys-A7-50T-Master" | "au250":
				return False
			case "au280" | "au50":
				return True
			case _:
				assert False, f"BOARD CONFIGURATION CHANGED DURING EXECUTION: {self._board}"


	def get_def_clock_domains(self) -> list[str]:
		match self._SIMPLYV_PROFILE:
			case "embedded":
				return ["MBUS_10", "MBUS_20", "MBUS_50", "MBUS_100"]
			case "hpc":
				return ["MBUS_10", "MBUS_20", "MBUS_50", "MBUS_100", "MBUS_250"]
			case _:
				assert False, f"SIMPLYV_PROFILE CONFIGURATION CHANGED DURING EXECUTION: {self._SIMPLYV_PROFILE}"
