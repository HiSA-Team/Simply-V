from typing import Any, Callable
from singleton import Singleton
from parsers.parser import Parser

class Bus_Parser(Parser, metaclass=Singleton):

	# Expand "Parser" properties to check

	mandatory_properties = Parser.mandatory_properties + ("PROTOCOL", "NUM_MI", "NUM_SI", 
						"MASTER_NAMES", "RANGE_NAMES",
						"RANGE_BASE_ADDR", "RANGE_ADDR_WIDTH")

	optional_properties = {
						 "ID_WIDTH" : 4, 
						 "ADDR_RANGES": 1
						 }

	type_parsers: dict[str, Callable[[str], Any]]= Parser.type_parsers | {
						 "ID_WIDTH": int,
						 "NUM_MI": int,
						 "NUM_SI": int, 
						 "MASTER_NAMES": lambda s: s.split(" "),
						 "RANGE_NAMES": lambda s: s.split(" "),
						 "RANGE_BASE_ADDR": lambda s: [int(x, 16) for x in s.split(" ")],
						 "RANGE_ADDR_WIDTH": lambda s: [int(x) for x in s.split(" ")],
						}
	
	range_validators: dict[str, Callable[[Any], bool]] = Parser.range_validators | {
						 "ID_WIDTH":			lambda v: Parser._check_range(v, 4, 32),
						 "NUM_SI":				lambda v: Parser._check_range(v, 1, 16),
						 "RANGE_ADDR_WIDTH":	lambda vls: all([Parser._check_range(v, 1, 64) for v in vls]),
						}

	# intra rules expressed as lambdas producing (bool, message)
	# if "bool" is True then crash reporting "message"
	intra_rules: list[Callable[[dict], tuple[bool, str]]] = Parser.intra_rules + [
		lambda d: (
			d["NUM_MI"] != len(d["RANGE_NAMES"]),
			f"The NUM_MI value {d['NUM_MI']} does not match RANGE_NAMES len"
		),
		lambda d: (
			(d["NUM_MI"] * d["ADDR_RANGES"]) != len(d["RANGE_BASE_ADDR"]),
			f"NUM_MI * ADDR_RANGES does not match RANGE_BASE_ADDR len"
		),
		lambda d: (
			(d["NUM_MI"] * d["ADDR_RANGES"]) != len(d["RANGE_ADDR_WIDTH"]),
			f"NUM_MI * ADDR_RANGES does not match RANGE_ADDR_WIDTH len"
		),
		lambda d: (
			d["NUM_SI"] != len(d["MASTER_NAMES"]),
			f"NUM_SI does not match MASTER_NAMES len"
		),
	]

	protocol_min_width = {
		"AXI4": 12,
		"AXI4LITE": 1,
	}

	def _check_intra(self, data: dict):
		super()._check_intra(data)
		# protocol-dependent rule
		min_width = self.protocol_min_width.get(data["PROTOCOL"])
		if min_width is None:
			raise ValueError(f"Unsupported PROTOCOL: {data['PROTOCOL']}")

		if any(w < min_width for w in data["RANGE_ADDR_WIDTH"]):
			raise ValueError(f"RANGE_ADDR_WIDTH is less than {min_width}")	
