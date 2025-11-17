from typing import Any, Callable
from parsers.parser import Parser

class Sys_Parser(Parser):
	mandatory_properties = Parser.mandatory_properties + ("CORE_SELECTOR", "MAIN_CLOCK_DOMAIN")

	optional_properties: dict[str, int] = Parser.optional_properties | {
											"VIO_RESETN_DEFAULT": 1,
											"XLEN": 32
											}

	type_parsers: dict[str, Callable[[str], Any]]= Parser.type_parsers | {
			"XLEN": int,
			"VIO_RESETN_DEFAULT": bool,
			"PHYSICAL_ADDR_WIDTH": int
			}
	
	range_validators: dict[str, Callable[[Any], bool]] = Parser.range_validators | {
			"PHYSICAL_ADDR_WIDTH": lambda v: Parser._check_range(v, 32, 64),
			"XLEN": lambda v: ((v == 32) or (v == 64))
			}

	# intra rules expressed as lambdas producing (bool, message)
	intra_rules: list[Callable[[dict], tuple[bool, str]]] = Parser.intra_rules + [
			lambda d: (
				(d["XLEN"] == 32) and (d["PHYSICAL_ADDR_WIDTH"] != 32),
				f"PHYSICAL_ADDR_WIDTH doesn't match when XLEN = 32"
				),
			lambda d: (
				(d["CORE_SELECTOR"] == "CORE_MICROBLAZEV_RV64" and d["XLEN"] == 32) or \
				(d["CORE_SELECTOR"] == "CORE_MICROBLAZEV_RV32" and d["XLEN"] == 64),
				f"XLEN={d['XLEN']} doesn't match {d['CORE_SELECTOR']} data width."
				),
			lambda d: (
				(d["XLEN"] == 64) and (d["PHYSICAL_ADDR_WIDTH"] == 32),
				"PHYSICAL_ADDR_WIDTH should be in range (32,64] when XLEN = 64"
				),
			lambda d: (
				(d["CORE_SELECTOR"] == "CORE_PICORV32") and (d["VIO_RESETN_DEFAULT"] != 0),
				f"CORE_PICORV32 only supports VIO_RESETN_DEFAULT == 0!"
				)
		]
