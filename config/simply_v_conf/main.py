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
import traceback


def parse_args():
	# Each argument corresponds directly to a Makefile variable passed
	# in the various CONFIG_*_ARGS groups.
	parser = argparse.ArgumentParser()

	# =====================
	# Input CSV files
	# (INPUT_*_CSV in Makefile, always passed)
	# =====================
	parser.add_argument("--system_csv", required=True)
	parser.add_argument("--mbus_csv", required=True)
	parser.add_argument("--pbus_csv", required=True)
	parser.add_argument("--hbus_csv", required=True)

	# =====================
	# Configuration modes
	# (enabled by Makefile targets: --config_mbus, --config_sw, etc.)
	# =====================
	parser.add_argument("--config_mbus", action="store_true")
	parser.add_argument("--config_pbus", action="store_true")
	parser.add_argument("--config_hbus", action="store_true")
	parser.add_argument("--config_sw", action="store_true")
	parser.add_argument("--config_xilinx", action="store_true")
	parser.add_argument("--config_dump", action="store_true")

	# =====================
	# MBUS outputs
	# =====================
	parser.add_argument("--mbus_tcl")
	parser.add_argument("--mbus_interconnect")
	parser.add_argument("--mbus_clock")

	# =====================
	# PBUS outputs
	# =====================
	parser.add_argument("--pbus_tcl")
	parser.add_argument("--pbus_interconnect")

	# =====================
	# HBUS outputs
	# =====================
	parser.add_argument("--hbus_tcl")
	parser.add_argument("--hbus_interconnect")
	parser.add_argument("--hbus_clock")

	# =====================
	# Software outputs
	# =====================
	parser.add_argument("--hal_conf")
	parser.add_argument("--sw_mk")
	parser.add_argument("--ld_conf")

	# =====================
	# Xilinx outputs
	# =====================
	parser.add_argument("--xilinx_mk")
	parser.add_argument("--ddr4_root")
	parser.add_argument("--bram_root")
	parser.add_argument("--uart_root")

	# =====================
	# Dump output
	# =====================
	parser.add_argument("--dump_path")

	return parser.parse_args()


def main(logger):
	args = parse_args()

	# (INPUT_ARGS) from Makefile 
	bus_input_files = {
		"MBUS": args.mbus_csv,
		"PBUS": args.pbus_csv,
		"HBUS": args.hbus_csv,
	}

	# Global initialization
	sys_parser = Sys_Parser.get_instance()
	env = Env.get_instance()
	env.set_inputs(bus_input_files)

	sys_dict = sys_parser.parse_csv(args.system_csv)
	# Create SimplyV main object that will also create the nodes hierarchy
	system = SimplyV(sys_dict)

	# Triggered by Makefile: config_mbus or all
	# =====================
	# MBUS
	# =====================
	if args.config_mbus:
		if not all([args.mbus_tcl, args.mbus_interconnect, args.mbus_clock]):
			raise ValueError(
				"config_mbus requires --mbus_tcl, --mbus_interconnect, and --mbus_clock"
			)

		outputs = [
			args.mbus_tcl,
			args.mbus_interconnect,
			args.mbus_clock,
		]

		if system.config_bus("MBUS", outputs):
			logger.simply_v_info("Generated MBUS configs")
		else:
			logger.simply_v_warning("MBUS configs NOT generated (bus disabled)")

	# Triggered by Makefile: config_pbus or all
	# =====================
	# PBUS
	# =====================
	if args.config_pbus:
		if not all([args.pbus_tcl, args.pbus_interconnect]):
			raise ValueError(
				"config_pbus requires --pbus_tcl and --pbus_interconnect"
			)

		outputs = [
			args.pbus_tcl,
			args.pbus_interconnect,
		]

		if system.config_bus("PBUS", outputs):
			logger.simply_v_info("Generated PBUS configs")
		else:
			logger.simply_v_warning("PBUS configs NOT generated (bus disabled)")
	

	# Triggered by Makefile: config_hbus or all
	# =====================
	# HBUS
	# =====================
	if args.config_hbus:
		if not all([args.hbus_tcl, args.hbus_interconnect, args.hbus_clock]):
			raise ValueError(
				"config_hbus requires --hbus_tcl, --hbus_interconnect, and --hbus_clock"
			)

		outputs = [
			args.hbus_tcl,
			args.hbus_interconnect,
			args.hbus_clock,
		]

		if system.config_bus("HBUS", outputs):
			logger.simply_v_info("Generated HBUS configs")
		else:
			logger.simply_v_warning("HBUS configs NOT generated (bus disabled)")

	# Triggered by Makefile: config_sw or all
	# =====================
	# Software
	# =====================
	if args.config_sw:
		if not all([args.hal_conf, args.sw_mk, args.ld_conf]):
			raise ValueError(
				"config_sw requires --hal_conf, --sw_mk, and --ld_conf"
			)

		system.create_hal_header(args.hal_conf)
		system.update_sw_makefile(args.sw_mk)
		system.create_linker_script(args.ld_conf)
		logger.simply_v_info("Generated software configs")

	# Triggered by Makefile: config_xilinx or all
	# =====================
	# Xilinx
	# =====================
	if args.config_xilinx:
		if not all([
			args.xilinx_mk,
			args.ddr4_root,
			args.bram_root,
			args.uart_root,
		]):
			raise ValueError(
				"config_xilinx requires --xilinx_mk, --ddr4_root, --bram_root, and --uart_root"
			)

		system.config_xilinx_makefile(args.xilinx_mk)
		system.config_xilinx_clock_domains(args.xilinx_mk)
		system.config_peripherals_ips([
			args.ddr4_root,
			args.bram_root,
			args.uart_root,
		])
		logger.simply_v_info("Generated Xilinx configs")
	
	# Triggered by Makefile: config_dump or all
	# =====================
	# Dump
	# =====================
	if args.config_dump:
		if not args.dump_path:
			raise ValueError(
				"config_dump requires --dump_path"
			)

		system.dump_reachability(args.dump_path)
		logger.simply_v_info("Generated reachability dump")


if __name__ == "__main__":
	logger = Logger.get_instance()
	try:
		main(logger)
	except ValueError as e:
		logger.simply_v_crash(f"Value error: {e.args[0]}")
	except Exception:
		logger.simply_v_crash(
			"Unexpected error:\n" + traceback.format_exc()
		)

