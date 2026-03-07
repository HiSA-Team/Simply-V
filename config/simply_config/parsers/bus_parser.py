# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: The class "Bus_Parser" inherits from the "Parser" class, extending the checked
# properties with the ones common to all Buses

from typing import Any, Callable
from general.singleton import Singleton
from .parser import Parser
from general.error import Unsupported_Value_Error, Conflict_Error

class Bus_Parser(Parser, metaclass=Singleton):

	# Expand "Parser" properties to check

	mandatory_properties = Parser.mandatory_properties + ("PROTOCOL",
							"MASTER_NAMES",
							"RANGE_NAMES",
							"RANGE_BASE_ADDR",
							"RANGE_ADDR_WIDTH",
							"ID_WIDTH",
							"ADDR_RANGES",
						)

	type_parsers: dict[str, Callable[[str], Any]]= Parser.type_parsers | {
							"ID_WIDTH": int,
							"ADDR_RANGES": int,
							"MASTER_NAMES": lambda s: s.split(),
							"RANGE_NAMES": lambda s: s.split(),
							"RANGE_BASE_ADDR": lambda s: [int(x, 16) for x in s.split()],
							"RANGE_ADDR_WIDTH": lambda s: [int(x) for x in s.split()],
						}

	range_validators: dict[str, Callable[[str, int], None]] = Parser.range_validators | {
						 "ID_WIDTH":			lambda n, v: Parser._check_range(n, v, 4, 32),
						 "ADDR_RANGES":			lambda n, v: Parser._check_range(n, v, 1, 16),
						 "RANGE_ADDR_WIDTH":	lambda n, vls: all([Parser._check_range(n, v, 1, 64) for v in vls]),
						 "RANGE_NAMES":			lambda n, names: Parser._check_range(n, len(names), 1, 16),
						 "MASTER_NAMES":		lambda n, names: Parser._check_range(n, len(names), 1, 16)
						}

	intra_rules: list[Callable[[dict], tuple[bool, Exception]]] = Parser.intra_rules + [
		lambda d: (
			(len(d["RANGE_NAMES"]) * d["ADDR_RANGES"]) != len(d["RANGE_BASE_ADDR"]),
			Conflict_Error("RANGE_NAMES", "ADDR_RANGES", \
					"RANGE_NAMES len * ADDR_RANGES does not match RANGE_BASE_ADDR len")
		),
		lambda d: (
			(len(d["RANGE_NAMES"]) * d["ADDR_RANGES"]) != len(d["RANGE_ADDR_WIDTH"]),
			Conflict_Error("RANGE_NAMES", "ADDR_RANGES", \
					"RANGE_NAMES len * ADDR_RANGES does not match RANGE_ADDR_WIDTH len")
		),
	]

	# Added attribute to check for minimum widths of supported protocols
	protocol_min_width = {
		"AXI4": 12,
		"AXI4LITE": 1,
	}

	# Extend "Parser" "_check_intra" logic to also check protocol_min_width
	def _check_intra(self, data: dict):
		super()._check_intra(data)
		# protocol-dependent rule
		min_width = self.protocol_min_width.get(data["PROTOCOL"])
		if min_width is None:
			raise Unsupported_Value_Error("PROTOCOL", data["PROTOCOL"], list(self.protocol_min_width.keys()))

		if any(w < min_width for w in data["RANGE_ADDR_WIDTH"]):
			raise Conflict_Error("PROTOCOL", "RANGE_ADDR_WIDTH", f"Value is less than {min_width}")

	def __init__(self):
		super().__init__()
