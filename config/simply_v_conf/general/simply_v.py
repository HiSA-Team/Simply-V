# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This class is the starting point for all the configuration targets
# the purpose of this class is:
# .1 Create the "MBUS" object (which is the root node of the buses and peripherals tree)
# .2 Launch all the configurations checks through the "init_configurations" method of MBUS 
# .3 Launch all the file generations/modifications that will be needed from the "sw" and "hw"
#	 flows
#
# all the targets of the makefile in the "config root" are compatible with the simply_v methods
# through the "main.py" file that launches the correct methods based on the makefile target that
# launched the whole configuration

import re
from buses.nonleafbus import NonLeafBus
from templates.halheader_template import HALheader_Template
from templates.crossbar_template import Crossbar_Template
from templates.clocks_template import Clocks_Template
from templates.ld_template import Ld_Template
from peripherals.ddr4 import DDR4
from peripherals.bram import Bram
from templates.svinc_template import SVinc_Template 
from pathlib import Path
from factories.buses_factory import Buses_Factory
from peripherals.peripheral import Peripheral
from peripherals.uart import Uart
from .singleton import Singleton
from buses.mbus import MBus
from .logger import Logger

class SimplyV(metaclass=Singleton):
	buses_factory = Buses_Factory.get_instance()
	logger = Logger.get_instance()
	SUPPORTED_CORES = ("CORE_PICORV32", "CORE_CV32E40P", "CORE_IBEX", "CORE_MICROBLAZEV_RV32", \
										"CORE_MICROBLAZEV_RV64", "CORE_DUAL_MICROBLAZEV_RV32", \
										"CORE_CV64A6", "CORE_CV64A6_ARA")

	def __init__(self, system_data: dict):
		self.CORE_SELECTOR: str = system_data["CORE_SELECTOR"]
		self.MAIN_CLOCK_DOMAIN: str = system_data["MAIN_CLOCK_DOMAIN"]
		self.VIO_RESETN_DEFAULT: int = system_data["VIO_RESETN_DEFAULT"]
		self.XLEN: int = system_data["XLEN"]
		self.PHYSICAL_ADDR_WIDTH: int = system_data["PHYSICAL_ADDR_WIDTH"]
		self.BOOT_MEMORY_BLOCK: str = system_data["BOOT_MEMORY_BLOCK"]
		self.mbus: MBus

		main_clock_frqz = self.buses_factory.extract_clock_frequency(self.MAIN_CLOCK_DOMAIN)

		# CV64A6_ARA needs this particular check
		if ((main_clock_frqz > 50) and (self.CORE_SELECTOR == "CORE_CV64A6_ARA")):
			raise ValueError("CORE_CV64A6_ARA supports a maximum MAIN_CLOCK_DOMAIN frequency of 50 MHz." 
							 f"(configured with {self.MAIN_CLOCK_DOMAIN})")

		if (self.CORE_SELECTOR not in self.SUPPORTED_CORES):
			raise ValueError("CORE_SELECTOR unsupported")

		# Create root node (MBUS)
		asgn_base_addr = [0]
		asgn_addr_width = [self.PHYSICAL_ADDR_WIDTH]
		clock_domain = self.MAIN_CLOCK_DOMAIN

		self.mbus = self.buses_factory.create_bus("MBUS", asgn_base_addr, asgn_addr_width, clock_domain,\
												axi_addr_width=self.PHYSICAL_ADDR_WIDTH, axi_data_width=self.XLEN)

		self.mbus.init_configurations()
		# get ALL the peripherals and buses on the configuration
		self.peripherals = self.mbus.get_peripherals(recursive=True)
		self.buses = [self.mbus]
		tree_buses = self.mbus.get_buses(recursive=True)
		if(tree_buses):
			self.buses.extend(tree_buses)

		# differentiate memories from normal devices 
		self.devices: list[Peripheral] = []
		self.memories: list[Peripheral] = []

		for p in self.peripherals:
			if(p.IS_A_MEMORY):
				self.memories.append(p)
			else:
				self.devices.append(p)
		
	# Create linker script used from the "sw" flow
	def create_linker_script(self, ld_file_name: str):
		template = Ld_Template(self.memories, self.BOOT_MEMORY_BLOCK)
		template.write_to_file(ld_file_name)


	# Dump reachability file containing all the main information about all the peripherals
	# in the configuration
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

	
	# Create HAL header used from the "sw" flow
	def create_hal_header(self, hal_hdr_file_name: str) -> None:
		template = HALheader_Template(self.peripherals, self.devices)
		template.write_to_file(hal_hdr_file_name)
		

	# Update the "sw" makefile with the corresponding XLEN selected
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


	# Generate all the configuration files of each bus:
	# SVINC files to use for crossbar ports declarations
	# config.tcl files to automatically configure the Xilinx Interconnect IP
	# CLOCK SVINC files (NonLeafBuses only) to configure the clock domains of the SOC
	def config_bus(self, target_bus: str, outputs: list[str]) -> bool:
		for bus in self.buses:
			if bus.FULL_NAME == target_bus.upper():
				crossbar_template = Crossbar_Template(bus)
				crossbar_template.write_to_file(outputs[0])
				svinc_template = SVinc_Template(bus)
				svinc_template.write_to_file(outputs[1])
				# only NonLeafBus need to configure the clock svinc file
				if isinstance(bus, NonLeafBus):
					clock_template = Clocks_Template(bus)
					clock_template.write_to_file(outputs[2])
				return True

		# return false if the bus wasn't found
		return False



	# Update the "hw" makefile with the corresponding "sys_targets" and "bus_targets" selected
	# used from Vivado 
	def config_xilinx_makefile(self, xilinx_makefile: str) -> None:
		makefile_path = Path(xilinx_makefile)
		content = makefile_path.read_text()

		# System targets to replace
		sys_targets = ["CORE_SELECTOR", "VIO_RESETN_DEFAULT", "XLEN", "PHYSICAL_ADDR_WIDTH"]

		# Replace system targets with "self" values
		for t in sys_targets:
			# Example pattern: "XLEN ?= 32"
			pattern = rf"^{t}\s*\?=\s*.*$"
			replacement = f"{t} ?= {getattr(self, t)}" # getattr retrieve the corresponding "self" value
			content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

		# Bus targets
		bus_targets_suffixes = ["NUM_SI", "NUM_MI", "ID_WIDTH"]
		# MBUS has additional targets
		mbus_targets = [("MBUS_ADDR_WIDTH", "ADDR_WIDTH"), ("MBUS_DATA_WIDTH", "DATA_WIDTH")]

		for bus in self.buses:
			base = bus.FULL_NAME  # e.g. "MBUS", "PBUS", "HBUS"
			for suffix in bus_targets_suffixes:
				target = base + "_" + suffix
				# Example pattern: "MBUS_NUM_SI ?= 5"
				pattern = rf"^{target}\s*\?=\s*.*$"
				replacement = f"{target} ?= {getattr(bus, suffix)}" # getattr retrieve the corresponding "bus" value
				content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

			if (base == "MBUS"):
				for target, name in mbus_targets:
					# Example pattern: "MBUS_ADDR_WIDTH ?= 32" where "32" is mbus.ADDR_WIDTH parameter
					# Example pattern: "MBUS_ADDR_WIDTH ?= 32" where "32" is mbus.DATA_WIDTH parameter
					pattern = rf"^{target}\s*\?=\s*.*$"
					replacement = f"{target} ?= {getattr(bus, name)}"
					content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

		makefile_path.write_text(content)



	# Update the "hw" makefile with the "HAS_CLOCK_DOMAIN" values, used to conditionally istantiate
	# clock converters (at the rtl level) in order to adapt different clock domains
	def config_xilinx_clock_domains(self, file_name: str) -> None:
		children_nodes = self.mbus.get_nodes()
		prefix = "_HAS_CLOCK_DOMAIN"
		makefile_variable = ["MAIN_CLOCK_DOMAIN"]

		# construct clock domain list
		for n in children_nodes:
			if n.CLOCK_DOMAIN != self.mbus.CLOCK_DOMAIN:
				makefile_variable.append(n.FULL_NAME + prefix)

		makefile_variable_str = " ".join(makefile_variable)

		output_mk_file = Path(file_name)
		content = output_mk_file.read_text()

		# Replace RANGE_CLOCK_DOMAINS
		pattern_range = rf"^RANGE_CLOCK_DOMAINS\s*\?=\s*.*$"
		replacement_range = f"RANGE_CLOCK_DOMAINS ?= {makefile_variable_str}"
		content = re.sub(pattern_range, replacement_range, content, flags=re.MULTILINE)

		# Replace MAIN_CLOCK_FREQ_MHZ
		pattern_freq = rf"^MAIN_CLOCK_FREQ_MHZ\s*\?=\s*.*$"
		replacement_freq = f"MAIN_CLOCK_FREQ_MHZ ?= {self.mbus.CLOCK_FREQUENCY}"
		content = re.sub(pattern_freq, replacement_freq, content, flags=re.MULTILINE)

		output_mk_file.write_text(content)

	# Trigger specific peripherals IPs configurations
	def config_peripherals_ips(self, files: list[str]) -> None:
		for p in self.peripherals:
			if isinstance(p, DDR4):
				p.config_ip(files[0])
			if isinstance(p, Bram):
				# divide for XLEN_bytes
				xlen_bytes = int(self.XLEN / 8)
				p.config_ip(files[1], xlen_bytes=xlen_bytes)
			if isinstance(p, Uart):
			 	p.config_ip(files[2])
