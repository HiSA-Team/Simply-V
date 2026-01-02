# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: The class "MBUS_Parser" inherits from the "NonLeafBus_Parser" class, extending the checked
# properties with the "MBUS" specific ones (RANGE_CLOCK_DOMAINS)

from .nonleafbus_parser import NonLeafBus_Parser

class MBUS_Parser(NonLeafBus_Parser):
	#extend the father defined data structs used for parsing/validation
	mandatory_properties = NonLeafBus_Parser.mandatory_properties + ("RANGE_CLOCK_DOMAINS",)

	type_parsers = NonLeafBus_Parser.type_parsers | {"RANGE_CLOCK_DOMAINS": lambda s: s.split(" ")}

	intra_rules = NonLeafBus_Parser.intra_rules + [
			lambda d: (
				d["NUM_MI"] != len(d["RANGE_CLOCK_DOMAINS"]),
				f"NUM_MI does not match RANGE_CLOCK_DOMAINS len"
				)
			]

	def __init__(self):
		pass

