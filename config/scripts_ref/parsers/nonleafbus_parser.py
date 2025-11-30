# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: The class "NonLeafBus_Parser" inherits from the "Bus_Parser" class, extending the checked
# properties with the ones common to all NonLeafBusses

from .bus_parser import Bus_Parser

class NonLeafBus_Parser(Bus_Parser):
	#extend the father defined data structs used for parsing/validation
	mandatory_properties = Bus_Parser.mandatory_properties + ("RANGE_CLOCK_DOMAINS",)

	optional_properties = Bus_Parser.optional_properties | {"LOOPBACK": 0 }
	
	type_parsers = Bus_Parser.type_parsers | {"RANGE_CLOCK_DOMAINS": lambda s: s.split(" "),
											  "LOOPBACK": bool}

	intra_rules = Bus_Parser.intra_rules + [
			lambda d: (
				d["NUM_MI"] != len(d["RANGE_CLOCK_DOMAINS"]),
				f"NUM_MI does not match RANGE_CLOCK_DOMAINS len"
				),
			lambda d:(
				(d["LOOPBACK"] == 1) and (d["ADDR_RANGES"] != 1),
				f"ADDR_RANGES must be 1 when activating LOOPBACK"
				),
			#error if LOOPBACK is enabled, the protocol is AXI4 and there is atleast 1 range with
			#less than 13 addr_width value
			lambda d:(
				(d["LOOPBACK"] == 1) and (d["PROTOCOL"] == "AXI4") and any(x <= 12 for x in d["RANGE_ADDR_WIDTH"]),
				f"When enabling LOOPBACK all the RANGE_ADDR_WIDTH "
				"should be at least 13 when using AXI4 "
				"the Bus uses internally this extra bit "
				"to rearrange RANGES in order to accomodate "
				"the loopback configuration"	
				)
			]

	def __init__(self):
		pass
