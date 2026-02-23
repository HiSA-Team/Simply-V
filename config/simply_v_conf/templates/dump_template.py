# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: utility class to write a "dump.csv" describing all the main informations about peripherals
# in the configuration.

from peripherals.peripheral import Peripheral
from .template import Template
import textwrap

class Dump_Template(Template):
	# using "dedent" to ignore leading spaces
	_str_template: str = textwrap.dedent("""\
	NAME,BASE_ADDR,END_ADDR,CLOCK_DOMAIN,{buses_list_hdr}
	{csv_body}
	""")

	# The dumping information of each Peripheral need to be explicited on ranges granularity if either:
	# - Address ranges of the peripheral aren't contiguous (need to show different base and end addresses for each range)
	# - Reachability informations aren't equal on each range address (need to show different ranges reachability for some buses)
	def _get_body(self, buses: list[str], peripherals: list[Peripheral]):
		rows = []
		for p in peripherals:
			# starting with both get_reachable_from and get_range_dimensions without explicit values

			# key = RANGE_NAME (FULL_NAME of peripheral if it's composed of only 1 range or contiguous ranges)
			# value = (RANGE_BASE, RANGE_END, RANGE_LENGTH)
			reach_dict = p.assigned_addr_ranges.get_reachable_from(explicit=False)
			# key = RANGE_NAME (FULL_NAME of peripheral if it's composed of only 1 range or same reachables ranges)
			# value = copy of REACHABLE_FROM
			dim_dict = p.assigned_addr_ranges.get_range_dimensions(explicit=False)

			# check different reachable informations case
			if p.FULL_NAME not in reach_dict:
				# adapt dims to address range granularity
				dim_dict = p.assigned_addr_ranges.get_range_dimensions(explicit=True)

			# ranges uncontiguous case
			if p.FULL_NAME not in dim_dict:
				# adapt reachable to address range granularity
				reach_dict = p.assigned_addr_ranges.get_reachable_from(explicit=True)

			for key, value in reach_dict.items():
				list_of_reachables = ["N"] * len(buses)
				for full_name in value:
					position = buses.index(full_name)
					list_of_reachables[position] = "Y"

				str_of_reachables = ",".join(list_of_reachables)
				#write row
				rows.append(f"{key},{hex(dim_dict[key][0])},{hex(dim_dict[key][1]-1)},{p.CLOCK_DOMAIN},{str_of_reachables}")

		return "\n".join(rows)

	def __init__(self, peripherals: list[Peripheral]):
		#Avoid duplicates
		buses = set()
		for p in peripherals:
			reach_dict = p.assigned_addr_ranges.get_reachable_from(explicit=False)
			for value in reach_dict.values():
				buses.update(value)

		#"buses_list" is the source of truth for the rest of the configuration
		#in order to have coherent results about the same bus in different rows (peripherals)
		buses_list = list(sorted(buses))
		#HEADER
		self.buses_list_hdr = ",".join(buses_list)
		#BODY
		self.csv_body = self._get_body(buses_list, peripherals)


	# Used by template.py in the write_to_file implementation
	def get_params(self) -> dict[str, str]:
		return {
				"buses_list_hdr": self.buses_list_hdr,
				"csv_body": self.csv_body
				}
