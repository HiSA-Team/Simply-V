# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: The class "Parser" is the base class from which all the concrete parsers inherit.
# This class is designed in a declarative style to allow for future extensions of the checks
# performed by the parsers implementations to be easily added without changing the functions implementations.
# The "Parser" class implements the function "parse_csv" that is the only "public" function that should be called
# on a parser object.
# The "parse_csv" function calls all the internal functions used for the effective parsing and checking of the data
# and crashes the execution if an error is encountered during parsing.
# The "declarative" nature of the implementation lies in the fact that child classes must only define their
# "properties" and "rules" according to the checks they need to fulfil extending the ones defined by the
# "father" classes and the validation and checks functions will do the rest.

import pandas as pd
from typing import Any, Callable, NoReturn
from general.logger import Logger
from general.singleton import SingletonABCMeta

class Parser(metaclass=SingletonABCMeta):
	logger = Logger.get_instance()

	# Children classes expand these and implicitly use them (in _validate_values)
	# when parsing a file

	# These are the properties that if missing in the .csv file will lead to a crash
	mandatory_properties = ()

	# These are the properties that if missing in the .csv file will be initialized with a default value
	optional_properties: dict[str, Any] = {}

	# These are lambda functions that will cast the parsed values to the expected values
	# substituting the parsed values with the casted ones in the dictionary that "parse_csv" returns
	type_parsers: dict[str, Callable[[str], Any]]= {}
	
	# These are lambda functions that will return false if the check fails, true otherwise
	range_validators: dict[str, Callable[[Any], bool]] = {}

	# These are lambda functions that will check interactions between the parameters
	# they MUST return True in case of FAIL of the check
	intra_rules: list[Callable[[dict], tuple[bool, str]]] = []

	
	# Defined as static to be used from child classes to check integer ranges values
	@staticmethod
	def _check_range(value: int, min_value: int, max_value: int) -> bool:
		return min_value <= value <= max_value

	# Internal functions

	def _validate_mandatory(self, data: dict) -> None:
		missing = [k for k in self.mandatory_properties if k not in data]
		if missing:
			raise KeyError(f"Missing mandatory properties: {', '.join(missing)}")

	def _apply_defaults(self, data: dict) -> None:
		for key, default in self.optional_properties.items():
			data.setdefault(key, default)

	def _cast_and_validate(self, data: dict) -> None:
		for key, raw_value in data.items():
			if key in self.type_parsers:
				data[key] = self.type_parsers[key](raw_value)
			if key in self.range_validators:
				if not self.range_validators[key](data[key]):
					raise ValueError(f"Invalid value for {key}: {data[key]}")

	def _check_intra(self, data: dict) -> None:
		# run generic table-driven rules
		for rule in self.intra_rules:
			cond, msg = rule(data)
			if cond:
				raise ValueError(msg)

	def _validate_values(self, data: dict) -> None:
		self._validate_mandatory(data)
		self._apply_defaults(data)
		self._cast_and_validate(data)
		self._check_intra(data)

	# public function to be used publicly

	def parse_csv(self, file_name: str) -> dict | NoReturn:
		try:
			df = pd.read_csv(file_name, sep=",")
			data = dict(zip(df["Property"], df["Value"]))
			self._validate_values(data)
			return data

		except FileNotFoundError:
			self.logger.simply_v_crash(f"File error: {file_name} not found.")
		except KeyError as e:
			self.logger.simply_v_crash(f"Key error: {e.args[0]} in {file_name}.")
		except ValueError as e:
			self.logger.simply_v_crash(f"Value error: {e.args[0]} in {file_name}.")
		except Exception as e:
			self.logger.simply_v_crash(f"Unexpected error parsing {file_name}: {e}")
