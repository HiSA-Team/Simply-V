import re
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
		# get ALL the peripherals and buses on the configuration
		self.peripherals = self.mbus.get_peripherals(recursive=True)
		self.buses = [self.mbus]
		tree_buses = self.mbus.get_buses(recursive=True)
		if(tree_buses):
			self.buses.extend(tree_buses)

		self.devices: list[Peripheral] = []
		self.memories: list[Peripheral] = []

		for p in self.peripherals:
			if(p.IS_A_MEMORY):
				self.memories.append(p)
			else:
				self.devices.append(p)
		
	def create_linker_script(self, ld_file_name: str):
		# Currently only one copy of BRAM, DDR and HBM memory ranges are supported.
		template = Ld_Template(self.memories, self.BOOT_MEMORY_BLOCK)
		template.write_to_file(ld_file_name)

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
		template = HALheader_Template(self.peripherals, self.devices)
		template.write_to_file(hal_hdr_file_name)
		
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


	def config_bus(self, target_bus: str, outputs: list[str]) -> None:
		for bus in self.buses:
			if bus.FULL_NAME == target_bus.upper():
				crossbar_template = Crossbar_Template(bus)
				crossbar_template.write_to_file(outputs[0])
				svinc_template = SVinc_Template(bus)
				svinc_template.write_to_file(outputs[1])
				# only NonLeafBus need to configure the clock svinc file
				# MBUS need to generate the clocks template even if it doesn't generate clocks
				# for a "father" bus
				if bus.CAN_GENERATE_CLOCK or bus.FULL_NAME == "MBUS":
					clock_template = Clocks_Template(bus)
					clock_template.write_to_file(outputs[2])
				return

		raise ValueError(f"{target_bus} wasn't configured (crossbar and svinc gen.) because it wasn't found")


	def config_xilinx_makefile(self, xilinx_makefile: str) -> None:
		makefile_path = Path(xilinx_makefile)
		content = makefile_path.read_text()

		# System targets to replace
		sys_targets = ["CORE_SELECTOR", "VIO_RESETN_DEFAULT", "XLEN", "PHYSICAL_ADDR_WIDTH"]

		# Replace system targets
		for t in sys_targets:
			# Example pattern: "XLEN ?= 32"
			pattern = rf"^{t}\s*\?=\s*.*$"
			replacement = f"{t} ?= {getattr(self, t)}"
			content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

		# Bus targets
		bus_targets_suffixes = ["NUM_SI", "NUM_MI", "ID_WIDTH"]
		mbus_targets = [("MBUS_ADDR_WIDTH", "ADDR_WIDTH"), ("MBUS_DATA_WIDTH", "DATA_WIDTH")]

		for bus in self.buses:
			base = bus.FULL_NAME  # e.g. "MBUS", "PBUS", "HBUS"
			for suffix in bus_targets_suffixes:
				target = base + "_" + suffix
				pattern = rf"^{target}\s*\?=\s*.*$"
				replacement = f"{target} ?= {getattr(bus, suffix)}"
				content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

			if (base == "MBUS"):
				for target, name in mbus_targets:
					pattern = rf"^{target}\s*\?=\s*.*$"
					replacement = f"{target} ?= {getattr(bus, name)}"
					content = re.sub(pattern, replacement, content, flags=re.MULTILINE)

		makefile_path.write_text(content)
	
	def config_clock_domains(self, xilinx_makefile: str) -> None:
		return
		
	# need to generalize this to all the channels
	def config_ddr4_caches(self, ddr4_ch_0_cache: str) -> None:
		for p in self.peripherals:
			if isinstance(p, DDR4):
				if (p.CHANNEL == 0):
					cache_path = Path(ddr4_ch_0_cache)
					text = cache_path.read_text()

					base_hex = f"0x{p.get_base_addr():x}"
					# minus 1 because get_end_addr returns the first address OUTSIDE the range
					high_hex = f"0x{p.get_end_addr()-1:x}"

					text = re.sub(
						r"(set CACHE_BASEADDR)\s*\{[^}]+\}",
						rf"\1 {{{base_hex}}}",
						text
					)

					text = re.sub(
						r"(set CACHE_HIGHADDR)\s*\{[^}]+\}",
						rf"\1 {{{high_hex}}}",
						text
					)

					cache_path.write_text(text)

	# need to generalize this to different brams not only bram 0
	def config_brams(self, bram_0_file: str) -> None:
		bram_0_path = Path(bram_0_file)

		for p in self.peripherals:
			if isinstance(p, Bram):
				length = 0
				if (p.FULL_NAME == "BRAM_0"):
					# generalize to many ranges to compute the bram space address length
					dimensions = p.asgn_addr_ranges.get_range_dimensions(explicit=True)
					for values in dimensions.values():
						length += values[2]
					# divide for XLEN_bytes
					bram_depth = int(length / (self.XLEN / 8))
					content = bram_0_path.read_text()
					pattern = r"(set\s+bram_depth)\s*\{[^}]+\}"
					replacement = rf"\1 {{{bram_depth}}}"

					updated = re.sub(pattern, replacement, content)
					bram_0_path.write_text(updated)
