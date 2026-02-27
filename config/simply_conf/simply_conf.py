# Author: Salvatore Santoro	<sal.santoro@studenti.unina.it>
# Description: This is the entry point of the configuration flow.
# The purpose of this code is to dispatch the selected configuration target (from the config Makefile)
# to the actual python config implementation, creating the "Simply_V" object (the root of all the configurations)
# and using it to generate/modify the configuration files

from general.error import Simply_V_Error
from parsers.sys_parser import Sys_Parser
from general.env import Env
from general.logger import Logger
from general.simplyv import SimplyV
import argparse
import traceback

def parse_args():
	# Each argument corresponds directly to a Makefile variable passed
	# in the various CONFIG_*_ARGS groups.
	parser = argparse.ArgumentParser(
					description=(
					"Simply-Conf is Simply-V's configuration tool.\n\n"
					"This application is invoked by the config Makefile to\n"
					"parse CSV-based Buses informations and generate HW/SW \n"
					"configuration outputs.\n\n"
					),
					usage=argparse.SUPPRESS,
					formatter_class=argparse.RawTextHelpFormatter
			)

	# =====================
	# Input CSV files
	# (INPUT_*_CSV in Makefile, always passed)
	# =====================
	parser.add_argument(
		"--system_csv",
		required=True,
		help="System-level configuration CSV (global SoC description)"
	)
	parser.add_argument(
		"--mbus_csv",
		required=True,
		help="MBUS configuration CSV"
	)
	parser.add_argument(
		"--pbus_csv",
		required=True,
		help="PBUS configuration CSV"
	)
	parser.add_argument(
		"--hbus_csv",
		required=True,
		help="HBUS configuration CSV"
	)

	# =====================
	# Configuration modes
	# (enabled by Makefile targets: --config_mbus, --config_sw, etc.)
	# =====================

	parser.add_argument(
		"--config_mbus",
		action="store_true",
		help="Generate MBUS configuration outputs"
	)
	parser.add_argument(
		"--config_pbus",
		action="store_true",
		help="Generate PBUS configuration outputs"
	)
	parser.add_argument(
		"--config_hbus",
		action="store_true",
		help="Generate HBUS configuration outputs"
	)
	parser.add_argument(
		"--config_sw",
		action="store_true",
		help="Generate software configuration outputs"
	)
	parser.add_argument(
		"--config_xilinx",
		action="store_true",
		help="Generate Xilinx-specific configuration outputs"
	)
	parser.add_argument(
		"--config_dump",
		action="store_true",
		help="Generate reachability dump (CSV)"
	)


	# =====================
	# MBUS outputs
	# =====================
	parser.add_argument("--mbus_tcl", help="Output config.tcl file for MBUS crossbar")
	parser.add_argument("--mbus_interconnect", help="Output SVinc file for MBUS interconnect")
	parser.add_argument("--mbus_clock", help="Output SVinc file for MBUS clock assignments")

	# =====================
	# PBUS outputs
	# =====================

	parser.add_argument("--pbus_tcl", help="Output config.tcl file for PBUS crossbar")
	parser.add_argument("--pbus_interconnect", help="Output SVinc file for PBUS interconnect")

	# =====================
	# HBUS outputs
	# =====================
	parser.add_argument("--hbus_tcl", help="Output config.tcl file for HBUS crossbar")
	parser.add_argument("--hbus_interconnect", help="Output SVinc file for HBUS interconnect")
	parser.add_argument("--hbus_clock", help="Output SVinc file for HBUS clock assignments")

	# =====================
	# Software outputs
	# =====================
	parser.add_argument("--hal_conf", help="Output HAL configuration header")
	parser.add_argument("--sw_mk", help="Output software Makefile")
	parser.add_argument("--ld_root", help="Output linker script")

	# =====================
	# Xilinx outputs
	# =====================
	parser.add_argument("--xilinx_mk", help="Output Xilinx Makefile")
	parser.add_argument("--ddr4_root", help="Root directory for DDR4 IP generation")
	parser.add_argument("--bram_root", help="Root directory for BRAM IP generation")
	parser.add_argument("--uart_root", help="Root directory for UART IP generation")

	# =====================
	# Dump output
	# =====================
	parser.add_argument("--dump_path", help="Output path for reachability dump CSV")

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
			logger.simplyv_info("Generated MBUS configs")
		else:
			logger.simplyv_warning("MBUS configs NOT generated (bus disabled)")

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
			logger.simplyv_info("Generated PBUS configs")
		else:
			logger.simplyv_warning("PBUS configs NOT generated (bus disabled)")


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
			logger.simplyv_info("Generated HBUS configs")
		else:
			logger.simplyv_warning("HBUS configs NOT generated (bus disabled)")

	# Triggered by Makefile: config_sw or all
	# =====================
	# Software
	# =====================
	if args.config_sw:
		if not all([args.hal_conf, args.sw_mk, args.ld_root]):
			raise ValueError(
				"config_sw requires --hal_conf, --sw_mk, and --ld_root"
			)

		system.create_hal_header(args.hal_conf)
		system.update_sw_makefile(args.sw_mk)
		system.create_linker_script(args.ld_root)
		logger.simplyv_info("Generated software configs")

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
		logger.simplyv_info("Generated Xilinx configs")

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
		logger.simplyv_info("Generated reachability dump")


if __name__ == "__main__":
	logger = Logger.get_instance()
	try:
		main(logger)
	# Normal System Failure, we just need to show the custom error message
	except Simply_V_Error as e:
		logger.simplyv_crash(str(e))
	# Unexpected error we show the stack trace for debugging purposes
	except Exception:
		logger.simplyv_crash(
			"Unexpected error:\n" + traceback.format_exc()
		)
