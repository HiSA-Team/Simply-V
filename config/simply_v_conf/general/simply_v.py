import re
from templates.crossbar_template import Crossbar_Template
from templates.svinc_template import SVinc_Template 
from pathlib import Path
from factories.buses_factory import Buses_Factory
from peripherals.peripheral import Peripheral
import os
from .singleton import Singleton
from buses.mbus import MBus
from .logger import Logger

class SimplyV(metaclass=Singleton):
	buses_factory = Buses_Factory.get_instance()
	logger = Logger.get_instance()
	SUPPORTED_CORES = ("CORE_PICORV32", "CORE_CV32E40P", "CORE_IBEX", "CORE_MICROBLAZEV_RV32", \
										"CORE_MICROBLAZEV_RV64", "CORE_CV64A6")
	BOOT_MEMORY_BLOCK = 0x0

	def __init__(self, system_data: dict):
		self.CORE_SELECTOR: str = system_data["CORE_SELECTOR"]
		self.MAIN_CLOCK_DOMAIN: str = system_data["MAIN_CLOCK_DOMAIN"]
		self.VIO_RESETN_DEFAULT: int = system_data["VIO_RESETN_DEFAULT"]
		self.XLEN: int = system_data["XLEN"]
		self.PHYSICAL_ADDR_WIDTH: int = system_data["PHYSICAL_ADDR_WIDTH"]
		self.mbus: MBus

		if (self.CORE_SELECTOR not in self.SUPPORTED_CORES):
			raise ValueError("CORE_SELECTOR unsupported")

		# Create root node (MBUS)
		asgn_base_addr = [0]
		asgn_addr_width = [self.PHYSICAL_ADDR_WIDTH]
		clock_domain = self.MAIN_CLOCK_DOMAIN

		self.mbus = self.buses_factory.create_bus("MBUS", asgn_base_addr, asgn_addr_width, clock_domain,\
												axi_addr_width=self.PHYSICAL_ADDR_WIDTH, axi_data_width=self.XLEN)

		self.mbus.init_configurations()
		self.peripherals = self.mbus.get_peripherals()
		self.buses = self.mbus.get_buses()

	# simplyv
	def generate_crossbars_configs(self):
		return
	
	def create_linker_script(self, ld_file_name: str):
		# Currently only one copy of BRAM, DDR and HBM memory ranges are supported.
		memories: list[Peripheral]= []
		peripherals: list[Peripheral] = []

		# For each peripheral
		for p in self.peripherals:
			if(p.IS_A_MEMORY):
				memories.append(p)
			else:
				peripherals.append(p)

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
			dimension_dict = block.asgn_addr_ranges.get_range_dimensions(explicit=False)
			for key, value in dimension_dict.items():
				fd.write("\t" + key + " (xrw) : ORIGIN = 0x" + format(value[0], "016x") + ",  LENGTH = " + hex(value[2]) + "\n")

		fd.write("}\n")

		# Generate symbols from peripherals
		fd.write("\n")
		fd.write("/* Peripherals symbols */\n")
		base_addr_string = ""
		end_addr_string = ""

		for peripheral in peripherals:
			dimension_dict = peripheral.asgn_addr_ranges.get_range_dimensions(explicit=False)
			for key, value in dimension_dict.items():
				base_addr_string = "_peripheral_" + key + "_start = 0x" + format(value[0], "016x") + ";\n"
				end_addr_string = "_peripheral_" + key + "_end = 0x" + format(value[0], "016x") + ";\n"
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
			base_addr = mem.asgn_addr_ranges.get_base_addr()
			if (base_addr == self.BOOT_MEMORY_BLOCK):
				stack_start = mem.asgn_addr_ranges.get_end_addr()
				block_memory_name = mem.FULL_NAME
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

	def dump_reachability(self, dump_file_name: str):
		fd = open(dump_file_name,  "w")

		#Avoid duplicates
		buses = set()
		for p in self.peripherals:
			reach_dict = p.asgn_addr_ranges.get_reachable_from(explicit=True)
			for value in reach_dict.values():
				buses.update(value)

		#"buses_list" is the source of truth for the rest of the configuration
		#in order to have coherent results about the same bus in different rows (peripherals)
		buses_list = list(buses)

		#HEADER
		buses_list_hdr = ",".join(buses_list)
		fd.write(f"NAME,BASE_ADDR,END_ADDR,{buses_list_hdr}\n")

		#BODY
		for p in self.peripherals:
			reach_dict = p.asgn_addr_ranges.get_reachable_from(explicit=False)
			dim_dict = p.asgn_addr_ranges.get_range_dimensions(explicit=False)

			for key, value in reach_dict.items():
				list_of_reachables = ["N"] * len(buses_list)
				for full_name in value:
					position = buses_list.index(full_name)
					list_of_reachables[position] = "Y"

				str_of_reachables = ",".join(list_of_reachables)
				#write row
				fd.write(f"{key},{hex(dim_dict[key][0])},{hex(dim_dict[key][1]-1)},{str_of_reachables}\n")
	
	def create_hal_header(self, hal_hdr_file_name: str) -> None: 
		# Extract base name and make it a valid macro name for the include guard
		base_filename = os.path.basename(hal_hdr_file_name).replace('.', '_').upper()
		include_guard = f"__{base_filename}__"

		# Prepare the lines to write
		lines = [
			"// THIS FILE IS AUTOGENERATED, DON'T TOUCH!",
			f"#ifndef {include_guard}",
			f"#define {include_guard}",
			"",
		]

		# For each peripheral allocated in the configuration
		# check if the peripheral supports an HAL driver
		for p in self.peripherals:
			if(p.HAL_DRIVER):
				macro_name = f"{p.BASE_NAME}_IS_ENABLED"
				lines.append(f"#define {macro_name} 1")

		lines.append("")
		lines.append(f"#endif // {include_guard}")

		# Write to file (overwriting if it exists)
		with open(hal_hdr_file_name, 'w') as f:
			f.write("\n".join(lines))

		return

	def update_sw_makefile(self, sw_makefile: str) -> None:
		# read mk file
		sw_makefile_path = Path(sw_makefile)

		if not sw_makefile_path.is_file():
			raise FileNotFoundError(f"Missing file: {sw_makefile_path}")

		text = sw_makefile_path.read_text()

		# replace XLEN ?= <value>
		new_text = re.sub(
			r"XLEN\s*\?=.+",
			f"XLEN ?= {self.XLEN}",
			text
		)

		sw_makefile_path.write_text(new_text)


	def config_bus(self, target_bus: str, crossbar_file: str, svinc_file: str) -> None:
		for bus in self.buses:
			if bus.FULL_NAME == target_bus.upper():
				svinc_template = SVinc_Template(bus)
				crossbar_template = Crossbar_Template(bus)
				svinc_template.write_to_file(svinc_file)
				crossbar_template.write_to_file(crossbar_file)
				return

		self.logger.simply_v_error(f"{target_bus} wasn't configured (crossbar and svinc gen.) because it wasn't found")


	def config_xilinx(self, xilinx_makefile: str) -> None:
		return
