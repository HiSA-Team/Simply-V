import os
from buses.bus import Bus

class SVinc_Template:
	str_template: str = \
	f"// This file is auto-generated with {os.path.basename(__file__)}\n\n" \
	"/////////////////////////////////////////\n" \
	"// Buses declaration and concatenation //\n" \
	"/////////////////////////////////////////\n" \
	"\n" \
	"/////////////////\n" \
	"// AXI Masters //\n" \
	"/////////////////\n" \
	"{masters_str}" \
	"\n" \
	"/////////////////\n" \
	"// AXI Slaves  //\n" \
	"/////////////////\n" \
	"{slaves_str}" \
	"\n" \
	"//////////////////////////////////\n" \
	"// Concatenate AXI master buses //\n" \
	"//////////////////////////////////\n" \
	"{concatenated_masters}" \
	"\n" \
	"/////////////////////////////////\n" \
	"// Concatenate AXI slave buses //\n" \
	"/////////////////////////////////\n" \
	"{concatenated_slaves}"

	# Get the correct bus suffix depending on bus name
	def _get_width_params(self, bus: Bus) -> str:
		return bus.FULL_NAME + "_DATA_WIDTH, " \
			+ bus.FULL_NAME + "_ADDR_WIDTH, " \
			+ bus.FULL_NAME + "_ID_WIDTH"

	def _get_masters_to_bus(self, bus: Bus) -> list[str]:
		master_names = bus.MASTER_NAMES
		ret_list = []
		for name in master_names:
			# in the original "declare_and_concat" script also the masters were
			# reversed in order, so we keep the compatibility
			# (see _init_bus_to_slaves)
			ret_list.insert(0, f"{name}_to_{bus.FULL_NAME}")
		return ret_list
	
	def _get_bus_to_slaves(self, bus: Bus) -> list[str]:
		slaves_ranges = bus.get_ordered_children_ranges()
		ret_list = []
		for addr_range in slaves_ranges:
			# we're effectively "left appending" the names because the order need to be reversed
			# when concatenating signals arrays in order to be compatible with the 
			# crossbar generation code to match the "M" (slaves) ports of the crossbar.
			# The code we're generating in the "svinc" files will use macros to connect the slaves to the crossbar
			# but basically due to the way in which signals are defined in the RTL the names assigned to the signal
			# need to be reversed. (example slave in position 0 in the crossbar configuration file need to be the last
			# in the concatenation order and so on)
			ret_list.insert(0, f"{bus.FULL_NAME}_to_{addr_range.FULL_NAME}")
		return ret_list

	def _get_declaration_str(self, names_str) -> str:
		declarations = []
		for name in names_str:
			declarations.append(self.declare_prefix + "(" + name + ", " + self.width_params_str + ")")
		return "\n".join(declarations) + "\n"

	def _init_declare_masters(self) -> str:
		master_declarations = []
		for master_str in self.masters_to_bus_str:
			master_declarations.append(self.declare_prefix + "(" + master_str + ", " + self.width_params_str + ")")
		return "\n".join(master_declarations) + "\n"

	def _init_declare_slaves(self) -> str:
		slave_declarations = []
		for slave_str in self.bus_to_slaves_str:
			slave_declarations.append(self.declare_prefix + "(" + slave_str + ", " + self.width_params_str + ")")
		return "\n".join(slave_declarations) + "\n"

	def _get_concatenated_str(self, bus: Bus, master: bool) -> str:
		name = bus.FULL_NAME
		if(master):
			signals_name = name + "_masters"
			array_prefix = "_MASTERS_ARRAY"
			num_interfaces = bus.NUM_SI
			interfaces_suffix = "_NUM_SI"
			nodes_signals = self.masters_to_bus_str
		else:
			signals_name = name + "_slaves"
			array_prefix = "_SLAVES_ARRAY"
			num_interfaces = bus.NUM_MI
			interfaces_suffix = "_NUM_MI"
			nodes_signals = self.bus_to_slaves_str

		declare_array_str: str = self.declare_prefix + "_ARRAY" + \
							"(" + signals_name + ", " + \
							name + interfaces_suffix + ", " + \
							self.width_params_str + \
							")"
		
		concat_array_str: str = self.concat_prefix + array_prefix + \
							str(num_interfaces) + \
							"(" + signals_name + ", " + ", ".join(nodes_signals) +")"

		return declare_array_str + "\n" + concat_array_str + "\n"

	def __init__(self, bus: Bus):
		if (bus.PROTOCOL == "AXI4LITE"):
			self.declare_prefix: str =  "`DECLARE_AXILITE_BUS"
			self.concat_prefix: str = "`CONCAT_AXILITE"
		else:
			self.declare_prefix: str = "`DECLARE_AXI_BUS"
			self.concat_prefix: str = "`CONCAT_AXI"

		self.width_params_str: str = self._get_width_params(bus)
		self.masters_to_bus_str: list[str] = self._get_masters_to_bus(bus)
		self.bus_to_slaves_str: list[str] = self._get_bus_to_slaves(bus)
		self.declare_masters_str = self._get_declaration_str(self.masters_to_bus_str)
		self.declare_slaves_str = self._get_declaration_str(self.bus_to_slaves_str)
		self.concat_masters_str: str = self._get_concatenated_str(bus, True)
		self.concat_slaves_str: str = self._get_concatenated_str(bus, False)

	
	def write_to_file(self, file_name: str) -> None:
		formatted = self.str_template.format(masters_str = self.declare_masters_str, \
											slaves_str = self.declare_slaves_str, \
											concatenated_masters = self.concat_masters_str, \
											concatenated_slaves = self.concat_slaves_str
											)
		with open(file_name, "w", encoding="utf-8") as f:
			f.write(formatted)
