#!/bin/python3.10

from parsers.sys_parser import Sys_Parser
from general.env import Env
from general.simply_v import SimplyV


if __name__ == "__main__":
	#initialize Env (in env.py)
	env_global = Env.get_instance()
	#Parser for SimplyV params
	sys_parser = Sys_Parser.get_instance()
	
	#Paths
	sys_file = env_global.get_sys_file_path()
	linker_script_file = env_global.get_linker_script_path()
	peripherals_dump_file = env_global.get_peripherals_dump_path()
	
	#Parse SimplyV configs
	sys_dict = sys_parser.parse_csv(sys_file)
	system = SimplyV(sys_dict)

	#General dumps

	peripherals = system.get_peripherals()

	#Launch real SoC configurations
	system.create_linker_script(linker_script_file, peripherals)
	system.dump_reachability(peripherals_dump_file, peripherals)
	system.generate_crossbars_configs()
