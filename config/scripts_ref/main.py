#!/bin/python3.10

import simply_v
import os
import logging

# SoC Profile
soc_profile = os.environ["SOC_CONFIG"]
# Paths
configs_root = os.path.join(os.environ["CONFIG_ROOT"], "configs")
configs_common = os.path.join(configs_root, "common")
configs_embedded = os.path.join(configs_root, "embedded")
configs_hpc = os.path.join(configs_root, "hpc")

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

	system = simply_v.SimplyV(sys_config_file_path, mbus_config_path, soc_profile)
