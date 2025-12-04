import os
from .singleton import Singleton

class Env(metaclass=Singleton):
	# init Env
	def __init__(self):
		# Private variables never touch them, use the getters

		self.bus_input_files: dict[str, str]
		self._board = os.environ["BOARD"]
		# SoC Profile
		self._soc_profile = os.environ["SOC_CONFIG"]
			
	def set_inputs(self, bus_input_files: dict[str,str]):
		self.bus_input_files = bus_input_files

	def get_config_path(self, bus_name: str) -> str:
		return self.bus_input_files[bus_name]

	def get_soc_profile(self):
		return self._soc_profile

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
				raise ValueError("Unsupported Board configuration")


	def get_supp_hbm(self) -> bool | None:
		match self._board:
			case "Nexys-A7-100T-Master" | "Nexys-A7-50T-Master" | "au250":
				return False
			case "au280" | "au50":
				return True
			case _:
				raise ValueError("Unsupported Board configuration")
