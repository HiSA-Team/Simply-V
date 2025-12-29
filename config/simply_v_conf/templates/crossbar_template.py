# Author: Salvatore Santoro				<sal.santoro@studenti.unina.it>
# Description:
#   Class that can generate the config.tcl files for each crossbar in order to configure
#	the the Xilinx's axi_crossbar IP used by all the buses implementations

from buses.bus import Bus
import textwrap
import os

class Crossbar_Template:

	# using "dedent" to ignore leading spaces
	str_template: str = textwrap.dedent("""\
	// This file is auto-generated with {this_file}
	# Import IP
	create_ip -name axi_crossbar -vendor xilinx.com -library ip -version 2.1 -module_name $::env(IP_NAME)
	# Configure IP
	set_property -dict [list
	{bus_configs}
	 \\\n                         
	] [get_ips $::env(IP_NAME)]
	""")

	def _compose_index (self, index_int: int):
		index_string = ""
		if (index_int < 10):
			index_string = "0" + str(index_int)
		else:
			index_string = str(index_int)
		return index_string


	def _init_bus_configs(self, bus: Bus):
		config_list = []
		config_list.append("CONFIG.PROTOCOL {"          + bus.PROTOCOL          + "}")
		config_list.append("CONFIG.ADDR_WIDTH {"        + str(bus.ADDR_WIDTH)   + "}")
		config_list.append("CONFIG.DATA_WIDTH {"        + str(bus.DATA_WIDTH)   + "}")
		config_list.append("CONFIG.ID_WIDTH {"          + str(bus.ID_WIDTH)     + "}")
		config_list.append("CONFIG.NUM_SI {"            + str(bus.NUM_SI)       + "}")
		config_list.append("CONFIG.NUM_MI {"            + str(bus.NUM_MI)       + "}")
		config_list.append("CONFIG.ADDR_RANGES {"       + str(bus.CHILDREN_NUM_RANGES)  + "}")

		# Address ranges
		BASE_ADDR_config_list           = []
		RANGE_ADDR_WIDTH_config_list    = []

		slaves_ranges = bus.get_ordered_children_ranges()

		for interface_index, addr_ranges in enumerate(slaves_ranges):
			formatted_interface = self._compose_index(interface_index)
			for range_index, addr_range in enumerate(addr_ranges):
					formatted_range = self._compose_index(range_index)
					BASE_ADDR_config_list.append("CONFIG.M" + formatted_interface + "_A" + formatted_range + "_BASE_ADDR {"+hex(addr_range.RANGE_BASE_ADDR) +"}")
					RANGE_ADDR_WIDTH_config_list.append("CONFIG.M" + formatted_interface + "_A" + formatted_range + "_ADDR_WIDTH {" + str(addr_range.RANGE_ADDR_WIDTH) + "}")

		# Append to list
		config_list.extend(BASE_ADDR_config_list)
		config_list.extend(RANGE_ADDR_WIDTH_config_list)

		return " \\\n                         ".join(config_list)

	def __init__(self, bus: Bus):
		self.bus = bus
		self.bus_configs_str = self._init_bus_configs(bus)


	def write_to_file(self, file_name: str) -> None:
		formatted = self.str_template.format(
											this_file = os.path.basename(__file__),
											bus_configs = self.bus_configs_str
											)

		with open(file_name, "w", encoding="utf-8") as f:
			f.write(formatted)
