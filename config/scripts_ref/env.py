import os
from singleton import Singleton

class Env(metaclass=Singleton):
	# init Env
	def __init__(self):
		# Private variables never touch them, use the getters

		# SoC Profile
		self._soc_profile = os.environ["SOC_CONFIG"]
		# Configs Paths
		self._configs_root_path = os.path.join(os.environ["CONFIG_ROOT"], "configs")
		self._configs_common_path = os.path.join(self._configs_root_path, "common")
		self._configs_profile_path = os.path.join(self._configs_root_path, self._soc_profile)
		self._peripherals_dump_path = os.path.join(self._configs_root_path, "peripherals.csv")
		# System configs path
		self._sys_config_file_path = os.path.join(self._configs_common_path, "config_system.csv")
		# MBUS configs path
		self._mbus_config_file_path = os.path.join(self._configs_profile_path, "config_main_bus.csv")
		# SW Paths
		self._sw_soc_common = os.path.join(os.environ["SW_SOC_ROOT"], "common")
		self._linker_script_file_path = os.path.join(self._sw_soc_common, "UninaSoC.ld")

	def get_soc_profile(self):
		return self._soc_profile

	def get_conf_profile_path(self):
		return self._configs_profile_path

	def get_conf_common_path(self):
		return self._configs_common_path

	def get_sw_soc_common(self):
		return self._sw_soc_common

	def get_peripherals_dump_path(self):
		return self._peripherals_dump_path

	def get_linker_script_path(self):
		return self._linker_script_file_path
	
	def get_sys_file_path(self):
		return self._sys_config_file_path

	def get_mbus_file_path(self):
		return self._mbus_config_file_path

