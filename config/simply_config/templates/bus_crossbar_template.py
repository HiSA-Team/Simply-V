# Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
# Description:
#   Class that can generate the crossbar svinc file of a bus (MBUS, PBUS): the address map
#   localparams and the crossbar instance, either the Xilinx IP (XBAR_IMPL = XILINX) or the
#   in-tree RTL (XBAR_IMPL = CUSTOM). The in-tree crossbars decode one address range per
#   slave, so a child with more ranges is a configuration error with XBAR_IMPL = CUSTOM.

from buses.bus import Bus
from .template import Template
import os
import textwrap

AXI_SIGNALS = ["awid", "awaddr", "awlen", "awsize", "awburst", "awlock", "awcache", "awprot",
			   "awregion", "awqos", "awvalid", "awready", "wdata", "wstrb", "wlast", "wvalid", "wready",
			   "bid", "bresp", "bvalid", "bready", "arid", "araddr", "arlen", "arsize", "arburst",
			   "arlock", "arcache", "arprot", "arregion", "arqos", "arvalid", "arready",
			   "rid", "rdata", "rresp", "rlast", "rvalid", "rready"]
AXILITE_SIGNALS = ["awaddr", "awprot", "awvalid", "awready", "wdata", "wstrb", "wvalid", "wready",
				   "bresp", "bvalid", "bready", "araddr", "arprot", "arvalid", "arready",
				   "rdata", "rresp", "rvalid", "rready"]

# Clock and reset names in scope at the include site (simplyv.sv, pbus.sv)
CLOCK_RESET = {"MBUS": ("MBUS_clk", "MBUS_rstn"), "PBUS": ("PBUS_clock_i", "PBUS_reset_ni")}

class Bus_Crossbar_Template(Template):
	# using "dedent" to ignore leading spaces
	_str_template: str = textwrap.dedent("""\
	// This file is auto-generated with {this_file}

	/////////////////
	// Address map //
	/////////////////
	localparam logic [{bus}_NUM_MI-1:0][{bus}_ADDR_WIDTH-1:0] {bus}_XBAR_BASE = {{{bases}}};
	localparam logic [{bus}_NUM_MI-1:0][7:0] {bus}_XBAR_BITS = {{{bits}}};

	//////////////
	// Crossbar //
	//////////////
	generate if (XBAR_IMPL == XBAR_CUSTOM) begin : gen_{bus_lower}_xbar_custom
	    {custom_module} #(
	        .NUM_SI        ( {bus}_NUM_SI     ),
	        .NUM_MI        ( {bus}_NUM_MI     ),
	        .DATA_WIDTH    ( {bus}_DATA_WIDTH ),
	        .ADDR_WIDTH    ( {bus}_ADDR_WIDTH ),{id_width}
	        .MI_BASE       ( {bus}_XBAR_BASE  ),
	        .MI_RANGE_BITS ( {bus}_XBAR_BITS  )
	    ) {bus_lower}_xbar_u (
	{custom_ports}
	    );
	end else begin : gen_{bus_lower}_xbar_xilinx
	    xlnx_{bus_lower}_crossbar {bus_lower}_xbar_u (
	{xilinx_ports}
	    );
	end endgenerate
	""")

	def _get_map(self, bus: Bus, xbar_impl: str) -> tuple[str, str]:
		bases = []
		bits = []
		for addr_ranges in bus.get_ordered_children_ranges():
			ranges = list(addr_ranges)
			if xbar_impl == "CUSTOM" and len(ranges) != 1:
				raise ValueError(f"{bus.FULL_NAME}: XBAR_IMPL = CUSTOM supports one address range "
								 f"per slave, got {len(ranges)}")
			bases.insert(0, f"{bus.FULL_NAME}_ADDR_WIDTH'('h{ranges[0].RANGE_BASE_ADDR:x})")
			bits.insert(0, f"8'd{ranges[0].RANGE_ADDR_WIDTH}")
		# Concatenation: most significant first, i.e. master port NUM_MI-1 first
		return ", ".join(bases), ", ".join(bits)

	def _get_ports(self, bus: Bus, custom: bool) -> str:
		lite = (bus.PROTOCOL == "AXI4LITE")
		suffix = "axilite" if lite else "axi"
		port_suffix = "axilite" if (lite and custom) else "axi"
		clock, reset = CLOCK_RESET[bus.FULL_NAME]
		ports = [("aclk", clock), ("aresetn", reset)]
		for side, array in (("s", "masters"), ("m", "slaves")):
			for signal in (AXILITE_SIGNALS if lite else AXI_SIGNALS):
				# The Xilinx IP has no region signals on the slave side
				if signal.endswith("region") and side == "s" and not custom:
					continue
				ports.append((f"{side}_{port_suffix}_{signal}", f"{bus.FULL_NAME}_{array}_{suffix}_{signal}"))
		width = max(len(p) for p, _ in ports)
		return ",\n".join(f"        .{p:<{width}} ( {s} )" for p, s in ports)

	def __init__(self, bus: Bus, xbar_impl: str):
		self.bus = bus
		self.bases, self.bits = self._get_map(bus, xbar_impl)

	# Used by template.py in the write_to_file implementation
	def get_params(self) -> dict[str, str]:
		bus = self.bus
		lite = (bus.PROTOCOL == "AXI4LITE")
		return {
				"this_file": os.path.basename(__file__),
				"bus": bus.FULL_NAME,
				"bus_lower": bus.FULL_NAME.lower(),
				"bases": self.bases,
				"bits": self.bits,
				"custom_module": "simplyv_axilite_xbar" if lite else "simplyv_axi_xbar",
				"id_width": "" if lite else f"\n        .ID_WIDTH      ( {bus.FULL_NAME}_ID_WIDTH   ),",
				"custom_ports": self._get_ports(bus, True),
				"xilinx_ports": self._get_ports(bus, False)
				}
