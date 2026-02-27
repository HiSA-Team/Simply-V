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
from general.error import Missing_Parameter_Error, Invalid_Type_Error, Out_Of_Range_Error
from general.singleton import SingletonABCMeta

class Parser(metaclass=SingletonABCMeta):

	# Children classes expand these and implicitly use them (in _validate_values)
	# when parsing a file

	# These are the properties that if missing in the .csv file will lead to a crash
	mandatory_properties = ()

	# These are lambda functions that will cast the parsed values to the expected values
	# substituting the parsed values with the casted ones in the dictionary that "parse_csv" returns
	type_parsers: dict[str, Callable[[str], Any]]= {}
	
	# These are lambda functions that will throw and Out_Of_Range exception if the check fails 
	range_validators: dict[str, Callable[[str, int], None]] = {}

	# These are lambda functions that will check interactions between the parameters
	# they MUST return True in case of FAIL of the check
	intra_rules: list[Callable[[dict], tuple[bool, Exception]]] = []

	def __init__(self):
		self.logger = Logger.get_instance()
	
	# Defined as static to be used from child classes to check integer ranges values
	@staticmethod
	def _check_range(name: str, value: int, min_value: int, max_value: int):
		if not(min_value <= value <= max_value):
			raise Out_Of_Range_Error(name, value, min_value, max_value)

	# Internal functions

	def _validate_mandatory(self, data: dict) -> None:
		missing: list[str] = [k for k in self.mandatory_properties if k not in data]
		if missing:
			raise Missing_Parameter_Error(missing)

	def _cast_and_validate(self, data: dict) -> None:
		for key, raw_value in data.items():
			if key in self.type_parsers:
				try:
					data[key] = self.type_parsers[key](raw_value)
				except:
					raise Invalid_Type_Error(key, data[key])
			if key in self.range_validators:
				# throws Out_Of_Range_Exception
				self.range_validators[key](key, data[key])

	def _check_intra(self, data: dict) -> None:
		# run generic table-driven rules
		for rule in self.intra_rules:
			cond, exception = rule(data)
			if cond:
				raise exception

	def _validate_values(self, data: dict) -> None:
		self._validate_mandatory(data)
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
		except Exception as e:
			self.logger.simply_v_crash(f"{e} (in file {file_name})")
