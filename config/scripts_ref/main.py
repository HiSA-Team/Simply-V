#!/bin/python3.10

from simply_v import SimplyV
import logging
import os
from env import Env


if __name__ == "__main__":
	#initialize Env (in env.py)
	env_global = Env.get_instance()
	
	sys_file = env_global.get_sys_file_path()
	mbus_file = env_global.get_mbus_file_path()
	linker_script_file = env_global.get_linker_script_path()
	peripherals_dump_file = env_global.get_peripherals_dump_path()
	
	system = SimplyV(sys_file, mbus_file)

	system.print_vars()

	peripherals = system.get_peripherals()

	system.create_linker_script(linker_script_file, peripherals)
	system.dump_reachability(peripherals_dump_file, peripherals)
