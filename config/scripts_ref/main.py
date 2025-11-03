#!/bin/python3.10

from simply_v import SimplyV
import logging
import os
from env import *

if __name__ == "__main__":
	sys_config_file_path = os.path.join(configs_common, "config_system.csv")

	# Choose profile
	if (soc_profile == "hpc"):
		mbus_config_path = os.path.join(configs_hpc, "config_main_bus.csv")
	elif (soc_profile == "embedded"):
		mbus_config_path = os.path.join(configs_embedded, "config_main_bus.csv")
	else:
		logging.error("Unknown SoC profile")
		exit(1)

	system = SimplyV(sys_config_file_path, mbus_config_path)

	system.print_vars()

	peripherals = system.get_peripherals()

	system.create_linker_script(os.path.join(sw_soc_common, "UninaSoC.ld"), peripherals)
	system.dump_reachability(os.path.join(configs_root, "peripherals.csv"), peripherals)
