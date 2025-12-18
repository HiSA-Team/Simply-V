# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: utility class to write RTL file for CLOCKS declaration and assignments

import textwrap
from general.node import Node
from typing import cast
from buses.bus import Bus
import os


class Clocks_Template:
	# using "dedent" to ignore leading spaces
	str_template: str = textwrap.dedent("""\
	// This file is auto-generated with {current_file_path}

	/////////////////////////////////////////
	// Clocks declaration and assignments  //
	/////////////////////////////////////////

	{generated_clock}
	
	assign {bus_name}_clk = clk_{bus_clock_domain}MHz;
	assign {bus_name}_rstn = rstn_{bus_clock_domain}MHz;
	
	{clock_domains_block}

	""")

	def _init_clock_domains_block(self, children_nodes: list[Node]) -> str:
		lines = []
		for c in children_nodes:
			# Exclude nodes that can generate clocks like HBUS and DDR
			if c.CAN_GENERATE_CLOCK:
				continue

			name = c.FULL_NAME
			clock = c.CLOCK_DOMAIN

			lines.append(f"logic {name}_clk;")
			lines.append(f"assign {name}_clk = clk_{clock}MHz;")
			lines.append(f"logic {name}_rstn;")
			lines.append(f"assign {name}_rstn = rstn_{clock}MHz;")

		return "\n".join(lines)

	def __init__(self, bus: Bus):
		self.bus_clock_domain = bus.CLOCK_DOMAIN
		children_nodes = cast(list[Node], bus.get_buses(recursive=False))
		children_nodes += cast(list[Node], bus.get_peripherals(recursive=False))

		self.generated_clock = ""
		self.clock_domains_block = self._init_clock_domains_block(children_nodes)
		self.bus_name = bus.FULL_NAME

		# Generating output clock
		# MBus doesn't have this
		if(bus.CAN_GENERATE_CLOCK):
			self.generated_clock = f"assign {bus.FULL_NAME}_clk_o = clk_{bus.CLOCK_DOMAIN}MHz;"


	def write_to_file(self, file_name: str) -> None:
		formatted = self.str_template.format(
											current_file_path = os.path.basename(__file__),
											generated_clock = self.generated_clock,
											bus_name = self.bus_name,
											clock_domains_block = self.clock_domains_block,
											bus_clock_domain = self.bus_clock_domain
											)

		with open(file_name, "w", encoding="utf-8") as f:
			f.write(formatted)
