import re
from peripheral import Peripheral
from utils import *
from peripheral import Peripheral
import os
from mbus import MBus
from node import Node
from logger import Logger
from pprint import pprint

class SimplyV:
	def __init__(self, sys_config_file_name: str, mbus_file_name: str, soc_profile: str):
		# defaults
		self.SUPPORTED_CORES : list = ["CORE_PICORV32", "CORE_CV32E40P", "CORE_IBEX", "CORE_MICROBLAZEV_RV32", \
										"CORE_MICROBLAZEV_RV64", "CORE_CV64A6"]
		self.BOOT_MEMORY_BLOCK = 0x0
		self.EMBEDDED_SUPPORTED_CLOCKS : list[int] = [10, 20, 50, 100]
		self.HPC_SUPPORTED_CLOCKS : list[int] = [10, 20, 50, 100, 250]
		self.CORE_SELECTOR : str
		self.VIO_RESETN_DEFAULT : int = 1
		self.XLEN : int = 32
		self.PHYSICAL_ADDR_WIDTH : int = 32
		self.MAIN_CLOCK_DOMAIN : int
		self.logger: Logger = Logger(sys_config_file_name)
		self.soc_profile : str = soc_profile
		self.mbus : "MBus"
		
		# read config file
		system_data_dict = parse_csv(sys_config_file_name)

		# check and assign parameters

		try:
			self.check_assign_params(system_data_dict)
		except ValueError as e:
			self.logger.simply_v_crash(f"Invalid value type: {e}")

		# check params interactions
		self.check_intra()

		# Create root node (MBUS)
		axi_addr_width = self.PHYSICAL_ADDR_WIDTH
		axi_data_width = self.XLEN

		# MBUS has an addr_ranges of 1,
		# has a range_base_address of 0 and
		# a range_addr_width of all the PHYSICAL memory as convention
		asgn_addr_ranges = 1
		asgn_range_base_addr = [0]
		asgn_range_addr_width = [self.PHYSICAL_ADDR_WIDTH]
		clock = self.MAIN_CLOCK_DOMAIN

		mbus_data_dict = parse_csv(mbus_file_name)

		self.mbus = MBus(mbus_data_dict, mbus_file_name, axi_addr_width, axi_data_width, asgn_addr_ranges, \
								asgn_range_base_addr, asgn_range_addr_width, clock)

		pprint(vars(self.mbus))


	def check_assign_params(self, data_dict: dict):
		simply_v_crash = self.logger.simply_v_crash

		if ("CORE_SELECTOR" not in data_dict):
			simply_v_crash("CORE_SELECTOR is mandatory")

		self.CORE_SELECTOR = data_dict["CORE_SELECTOR"]
		
		if (self.CORE_SELECTOR not in self.SUPPORTED_CORES):
			simply_v_crash("CORE_SELECTOR unsupported")

		if ("VIO_RESETN_DEFAULT" in data_dict):
			self.VIO_RESETN_DEFAULT = int(data_dict["VIO_RESETN_DEFAULT"])
			if ((self.VIO_RESETN_DEFAULT != 0) and (self.VIO_RESETN_DEFAULT != 1)):
				simply_v_crash("VIO_RESETN_DEFAULT unexpected value")
	
		if ("XLEN" in data_dict):
			self.XLEN = int(data_dict["XLEN"])
			if ((self.XLEN != 32) and (self.XLEN != 64)):
				simply_v_crash("XLEN unexpected value")

		if ("PHYSICAL_ADDR_WIDTH" in data_dict):
			self.PHYSICAL_ADDR_WIDTH = int(data_dict["PHYSICAL_ADDR_WIDTH"])
			if(self.PHYSICAL_ADDR_WIDTH not in range(32,65)):
				simply_v_crash("PHYSICAL_ADDR_WIDTH can't be outside [32,64]")

		if ("MAIN_CLOCK_DOMAIN" not in data_dict):
			simply_v_crash("MAIN_CLOCK_DOMAIN is mandatory")

		self.MAIN_CLOCK_DOMAIN = int(data_dict["MAIN_CLOCK_DOMAIN"])


	def check_intra(self):
		simply_v_crash = self.logger.simply_v_crash

		# check XLEN and PHYSICAL_ADDR_WIDTH interaction
		if((self.XLEN == 32) and (self.PHYSICAL_ADDR_WIDTH != 32)):
			simply_v_crash("PHYSICAL_ADDR_WIDTH doesn't match when XLEN = 32")

		# check XLEN with MicroblazeV type interaction
		if ((self.CORE_SELECTOR == "CORE_MICROBLAZEV_RV64" and self.XLEN == 32) or \
			(self.CORE_SELECTOR == "CORE_MICROBLAZEV_RV32" and self.XLEN == 64)):
			simply_v_crash(f"XLEN={self.XLEN} doesn't match {self.CORE_SELECTOR} data width.")

		if((self.XLEN == 64) and ((self.PHYSICAL_ADDR_WIDTH == 32) or (self.PHYSICAL_ADDR_WIDTH > 64))):
			simply_v_crash("PHYSICAL_ADDR_WIDTH should be in range (32,64] when XLEN = 64")

		# check profile and MAIN_CLOCK_DOMAIN interaction
		if (self.soc_profile == "embedded"):
			if (self.MAIN_CLOCK_DOMAIN not in self.EMBEDDED_SUPPORTED_CLOCKS):
				simply_v_crash(f"Unsupported MAIN_CLOCK_DOMAIN value (supported values\
						for {self.soc_profile} profile: {self.EMBEDDED_SUPPORTED_CLOCKS})")
		else: #hpc
			if (self.MAIN_CLOCK_DOMAIN not in self.HPC_SUPPORTED_CLOCKS):
				simply_v_crash(f"Unsupported MAIN_CLOCK_DOMAIN value (supported values\
						for {self.soc_profile} profile: {self.HPC_SUPPORTED_CLOCKS})")

		## check CORE_SELECTOR and VIO_RESETN_DEFAULT interaction
		if self.CORE_SELECTOR == "CORE_PICORV32" and self.VIO_RESETN_DEFAULT != 0:
			simply_v_crash(f"CORE_PICORV32 only supports VIO_RESETN_DEFAULT = 0! {self.VIO_RESETN_DEFAULT}")

	
	def get_peripherals(self) -> list[Peripheral]:
		peripherals_names = set()
		peripherals = self.mbus.get_peripherals()
		# Check redundant names
		for p in peripherals:
			if (p.NAME in peripherals_names):
				self.logger.simply_v_crash("There are more peripherals with the same name"
							   f" in the configuration files (replicated name: {p.NAME})")
			
			peripherals_names.add(p.NAME)
		
		return peripherals

	
	def create_linker_script(self, ld_file_name: str, nodes: list[Peripheral]):
		# Currently only one copy of BRAM, DDR and HBM memory ranges are supported.
		memories: list[Peripheral]= []
		peripherals: list[Peripheral] = []

		# For each node
		for n in nodes:
			if(n.IS_A_MEMORY):
				memories.append(n)
			else:
				peripherals.append(n)

		# Create the Linker Script File
		fd = open(ld_file_name,  "w")

		# Write header
		fd.write("/* This file is auto-generated with " + os.path.basename(__file__) + " */\n")

		# Generate the memory blocks layout
		fd.write("\n")
		fd.write("/* Memory blocks */\n")
		fd.write("MEMORY\n")
		fd.write("{\n")

		for block in memories:
			# Generalizing on the number of RANGES
			idx = block.ASGN_ADDR_RANGES
			# Base is always the first base of the ranges
			base_addr = block.ASGN_RANGE_BASE_ADDR[0]
			# End addr is always the last base of the ranges
			end_addr = block.ASGN_RANGE_END_ADDR[idx-1]
			length = end_addr - base_addr
			fd.write("\t" + block.NAME + " (xrw) : ORIGIN = 0x" + format(base_addr, "016x") + ",  LENGTH = " + hex(length) + "\n")

		fd.write("}\n")

		# Generate symbols from peripherals
		fd.write("\n")
		fd.write("/* Peripherals symbols */\n")
		base_addr_string = ""
		end_addr_string = ""

		for peripheral in peripherals:
			ranges = peripheral.ASGN_ADDR_RANGES
			if (ranges == 1):
				base_addr = peripheral.ASGN_RANGE_BASE_ADDR[0]
				end_addr = peripheral.ASGN_RANGE_END_ADDR[0]
				base_addr_string = "_peripheral_" + peripheral.NAME + "_start = 0x" + format(base_addr, "016x") + ";\n"
				end_addr_string = "_peripheral_" + peripheral.NAME + "_end = 0x" + format(end_addr, "016x") + ";\n"
			else:
				# Place the a range identificator when a peripheral has more than one range
				for i in range(0, ranges):
					base_addr = peripheral.ASGN_RANGE_BASE_ADDR[i]
					end_addr = peripheral.ASGN_RANGE_END_ADDR[i]
					base_addr_string = "range_" + str(i) + "_peripheral_" + peripheral.NAME + "_start = 0x" + format(base_addr, "016x") + ";\n"
					end_addr_string = "range_" + str(i)+ "_peripheral_" + peripheral.NAME + "_end = 0x" + format(peripheral.ASGN_RANGE_END_ADDR[i], "016x") + ";\n"

			fd.write(base_addr_string)
			fd.write(end_addr_string)


		# Generate global symbols
		fd.write("\n")
		fd.write("/* Global symbols */\n")
		# Vector table is placed at the beggining of the boot memory block.
		# It is aligned to 256 bytes and is 32 words deep. (as described in risc-v spec)
		# We need to find the memory that has as a base address the boot address
		block_memory_base = 0
		block_memory_name = ""
		block_memory_range = 0
		stack_start = 0
		found = False

		for mem in memories:
			if(min(mem.ASGN_RANGE_BASE_ADDR) == self.BOOT_MEMORY_BLOCK):
				block_memory_base = min(mem.ASGN_RANGE_BASE_ADDR)
				block_memory_name = mem.NAME
				stack_start = max(mem.ASGN_RANGE_END_ADDR)
				found = True
				break

		if(not found):
			self.logger.simply_v_crash("Unable to find a BOOTABLE MEMORY"
										f"(Boot starting address is {hex(self.BOOT_MEMORY_BLOCK)})")


		vector_table_start = block_memory_base 
		fd.write("_vector_table_start = 0x" + format(vector_table_start, "016x") + ";\n")
		fd.write("_vector_table_end = 0x" + format(vector_table_start + 32*4, "016x") + ";\n")

		# The stack is allocated at the end of first memory block
		# _stack_end can be user-defined for the application, as bss and rodata
		# _stack_end will be aligned to 64 bits, making it working for both 32 and 64 bits configurations

		# Note: The memory size specified in the config.csv file may differ from the
		# physical memory allocated for the SoC (refer to hw/xilinx/ips/common/xlnx_blk_mem_gen/config.tcl).
		# Currently, the configuration process does not ensure alignment between config.csv
		# and xlnx_blk_mem_gen/config.tcl. As a result, we assume a maximum memory size of
		# 32KB for now, based on the current setting in `config.tcl`.


		fd.write("_stack_start = 0x" + format(stack_start, "016x") + ";\n")

		# Generate sections
		# vector table and text sections are here defined.
		# data, bss and rodata can be explicitly defined by the user application if required.
		fd.write("\n")
		fd.write("/* Sections */\n")
		fd.write("SECTIONS\n")
		fd.write("{\n")

		# Vector Table section
		fd.write("\t.vector_table _vector_table_start :\n")
		fd.write("\t{\n")
		fd.write("\t\tKEEP(*(.vector_table))\n")
		fd.write("\t}> " + block_memory_name + "\n")

		# Text section
		fd.write("\n")
		fd.write("\t.text :\n")
		fd.write("\t{\n")
		fd.write("\t\t. = ALIGN(32);\n")
		fd.write("\t\t_text_start = .;\n")
		fd.write("\t\t*(.text.handlers)\n")
		fd.write("\t\t*(.text.start)\n")
		fd.write("\t\t*(.text)\n")
		fd.write("\t\t*(.text*)\n")
		fd.write("\t\t. = ALIGN(32);\n")
		fd.write("\t\t_text_end = .;\n")
		fd.write("\t}> " + block_memory_name + "\n")

		fd.write("}\n")

		# Files closing
		fd.write("\n")
		fd.close()

