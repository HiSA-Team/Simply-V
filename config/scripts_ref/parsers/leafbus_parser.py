from parsers.bus_parser import Bus_Parser

class LeafBus_Parser(Bus_Parser):
	#extend the father defined data structs used for parsing/validation

	#enforce the number of SI interfaces to be equal to 1
	range_validators = Bus_Parser.range_validators | \
							   {"NUM_SI": lambda v: Bus_Parser._check_range(v, 1, 1)}

	def __init__(self):
		pass
