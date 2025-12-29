#!/usr/bin/env python3.10

# Author: Salvatore Santoro	<sal.santoro@studenti.unina.it>
# Description: This is the entry point of the configuration flow.
# The purpose of this code is to dispatch the selected configuration target (from the config Makefile)
# to the actual python config implementation, creating the "Simply_V" object (the root of all the configurations)
# and using it to generate/modify the configuration files

from parsers.sys_parser import Sys_Parser
from general.env import Env
from general.logger import Logger
from general.simply_v import SimplyV
import argparse

def parse_args():
	parser = argparse.ArgumentParser()

	parser.add_argument("--mode", required=True,
	choices=[
		"config_mbus", "config_pbus", "config_hbus",
		"config_sw", "config_xilinx", "config_dump",
		"config_check"
	])

	parser.add_argument("--system", required=True)
	parser.add_argument("--mbus", required=True)
	parser.add_argument("--pbus", required=True)
	parser.add_argument("--hbus", required=True)
	# Used only when configuring buses
	parser.add_argument("--target_bus", required=False)

	# everything after known args is treated as OUTPUT_FILES in the Makefile invocation
	args, output_files = parser.parse_known_args()
	args.output_files = output_files

	return args

def main(logger):
	args = parse_args()
	bus_input_files = {
		"MBUS":   args.mbus,
		"PBUS":   args.pbus,
		"HBUS":   args.hbus,
	}

	#Parser for SimplyV params
	sys_parser = Sys_Parser.get_instance()
	#initialize Env
	env = Env.get_instance()
	env.set_inputs(bus_input_files)

	#Parse SimplyV configs
	sys_dict = sys_parser.parse_csv(args.system)
	system = SimplyV(sys_dict)

	mode = args.mode
	outputs = args.output_files

	if mode == "config_check":
		# Configs are already checked after creating "SimplyV" object
		logger.simply_v_info(f"[CONFIG] Configuration check was successful.")
		return

	if mode in ("config_mbus", "config_pbus", "config_hbus"):
		if (len(outputs) != 2) and (len(outputs) != 3):
			raise ValueError(f"{mode} expects 2 or 3 output files, got {len(outputs)}")

		# first output is BUS crossbar
		# second output is BUS SVINC
		# third output (optional) is BUS CLOCK SVINC
		if(system.config_bus(args.target_bus, outputs)):
			logger.simply_v_info(f"[CONFIG] Generated {args.target_bus} configs.")
		else:
			logger.simply_v_warning(f"[CONFIG] {args.target_bus} configs NOT generated (bus disabled)")
		return

	if mode == "config_sw":
		if len(outputs) != 3:
			raise ValueError(f"{mode} expects 3 output files, got {len(outputs)}")
		# first output is HAL conf file
		system.create_hal_header(outputs[0])
		logger.simply_v_info("[CONFIG] Generated HAL header.")
		# second output is SW makefile
		system.update_sw_makefile(outputs[1])
		logger.simply_v_info("[CONFIG] Updated sw Makefile.")
		# third output is linker script file
		system.create_linker_script(outputs[2])
		logger.simply_v_info("[CONFIG] Generated linker script.")
		return

	if mode == "config_xilinx":
		if len(outputs) != 4:
			raise ValueError(f"{mode} expects 4 output files, got {len(outputs)}")
		# first output is xilinx makefile
		system.config_xilinx_makefile(outputs[0])
		system.config_xilinx_clock_domains(outputs[0])
		# second output is ddr4 ips root
		# third output is bram ips root
		# fourth output is uart ips root
		system.config_peripherals_ips(outputs[1:4])

		logger.simply_v_info("[CONFIG] Generated xilinx configs.")
		return

	if mode == "config_dump":
		if len(outputs) != 1:
			raise ValueError(f"{mode} expects 1 output file, got {len(outputs)}")
		system.dump_reachability(outputs[0])
		logger.simply_v_info("[CONFIG] Generated reachability dump.")
		return

	raise ValueError(f"Unknown mode {mode}")


if __name__ == "__main__":
	logger = Logger.get_instance()
	try:
		main(logger)
	except ValueError as e:
		logger.simply_v_crash(f"Value error: {e.args[0]}.")
	except Exception as e:
		logger.simply_v_crash(f"Unexpected error: {e}")
