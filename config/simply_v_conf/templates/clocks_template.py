# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: utility class to write RTL file for CLOCKS declaration and assignments

import textwrap
from general.node import Node
from typing import cast
from buses.nonleafbus import NonLeafBus
import os


class Clocks_Template:
	# using "dedent" to ignore leading spaces
	str_template: str = textwrap.dedent("""\
	// This file is auto-generated with {current_file_path}

	/////////////////////////////////////////
	// Clocks declaration and assignments  //
	/////////////////////////////////////////

	{generated_clock}
	
	assign {bus_name}_clk = {bus_clock_domain};
	assign {bus_name}_rstn = {bus_rstn};
	
	{clock_domains_block}

	""")

	def _init_clock_domains_block(self, children_nodes: list[Node]) -> str:
		lines = []
		for c in children_nodes:
			# Exclude nodes that can generate clocks like HBUS and DDR
			if c.IS_CLOCK_GENERATOR:
				continue

			name = c.FULL_NAME
			clock = c.CLOCK_DOMAIN

			lines.append(f"logic {name}_clk;")
			lines.append(f"assign {name}_clk = clk_{clock}MHz;")
			lines.append(f"logic {name}_rstn;")
			lines.append(f"assign {name}_rstn = rstn_{clock}MHz;")

		return "\n".join(lines)

	def __init__(self, bus: NonLeafBus):
		children_nodes = bus.get_nodes()

		self.clock_domains_block = self._init_clock_domains_block(children_nodes)
		self.bus_name = bus.FULL_NAME

		# Optional string
		self.generated_clock = ""

		# This bus doesn't generate clock but it takes it from the father bus
		if(not bus.IS_CLOCK_GENERATOR):
			# Buses that aren't generating a clock, need to have a father bus
			if (not bus.father):
				raise ValueError(f"Bus {bus.FULL_NAME} doesn't have a father bus for the clock generation")

			# take the clock from "_i" signal since the father bus will propagate it there
			self.bus_clock_domain = f"{bus.father.FULL_NAME}_clk_i"
			self.bus_rstn = f"{bus.father.FULL_NAME}_rstn_i"
		# This bus is generating its own clock
		else:
			# Take the clock from an "internal" clock domain
			self.bus_clock_domain = f"clk_{bus.CLOCK_DOMAIN}MHz"
			self.bus_rstn = f"rstn_{bus.CLOCK_DOMAIN}MHz"
			# If generating a clock while having a father bus propagate the clock to him
			# (MBUS doesn't have a father bus so it doesn't need this "_o" signal clock propagation)
			if(bus.father):
				self.generated_clock = f"assign {bus.FULL_NAME}_clk_o = clk_{bus.CLOCK_DOMAIN}MHz;"


	def write_to_file(self, file_name: str) -> None:
		formatted = self.str_template.format(
											current_file_path = os.path.basename(__file__),
											generated_clock = self.generated_clock,
											bus_name = self.bus_name,
											bus_rstn = self.bus_rstn,
											clock_domains_block = self.clock_domains_block,
											bus_clock_domain = self.bus_clock_domain
											)

		with open(file_name, "w", encoding="utf-8") as f:
			f.write(formatted)
