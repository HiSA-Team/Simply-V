# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: The class "Sys_Parser" inherits from the "Parser" class, extending the checked
# properties with the ones specific to system configurations

from typing import Any, Callable
from .parser import Parser
from general.error import Conflict_Error

class Sys_Parser(Parser):
	mandatory_properties = Parser.mandatory_properties + ("CORE_SELECTOR", "MAIN_CLOCK_DOMAIN", "PHYSICAL_ADDR_WIDTH",
														  "VIO_RESETN_DEFAULT", "XLEN", "BOOT_MEMORY_BLOCK")


	type_parsers: dict[str, Callable[[str], Any]]= Parser.type_parsers | {
			"XLEN": int,
			"VIO_RESETN_DEFAULT": int,
			"PHYSICAL_ADDR_WIDTH": int
			}

	range_validators: dict[str, Callable[[str, int], None]] = Parser.range_validators | {
			"PHYSICAL_ADDR_WIDTH": lambda p, v: Parser._check_range(p, v, 32, 64),
			}

	# intra rules expressed as lambdas producing (bool, message)
	# the value "True" of the bool MUST express an error in the configuration
	intra_rules: list[Callable[[dict], tuple[bool, Exception]]] = Parser.intra_rules + [
			lambda d: (
				(d["XLEN"] == 32) and (d["PHYSICAL_ADDR_WIDTH"] != 32),
				Conflict_Error("XLEN", "PHYSICAL_ADDR_WIDTH", "The values should match when XLEN = 32")
				),
			lambda d: (
				(d["CORE_SELECTOR"] in ["CORE_MICROBLAZEV_RV64", "CORE_CV64A6_ARA", "CORE_CV64A6"]
										and d["XLEN"] != 64) or \
				(d["CORE_SELECTOR"] in ["CORE_MICROBLAZEV_RV32", "CORE_PICORV32", "CORE_CV32E40P",
										"CORE_IBEX", "CORE_DUAL_MICROBLAZEV_RV32"] \
										and d["XLEN"] != 32),
				Conflict_Error("XLEN", "CORE_SELECTOR")
				),
			lambda d: (
				(d["XLEN"] == 64) and (d["PHYSICAL_ADDR_WIDTH"] == 32),
				Conflict_Error("XLEN", "PHYSICAL_ADDR_WIDTH", "PHYSICAL_ADDR_WIDTH should be in range (32,64]")
				),
			lambda d: (
				(d["CORE_SELECTOR"] == "CORE_PICORV32") and (d["VIO_RESETN_DEFAULT"] != 0),
				Conflict_Error("CORE_SELECTOR", "VIO_RESETN_DEFAULT", \
				   "CORE_PICORV32 only supports VIO_RESETN_DEFAULT == 0")
				)
		]

	def __init__(self):
		super().__init__()
