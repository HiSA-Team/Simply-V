from os import PRIO_PGRP
from pprint import pprint
import pandas as pd
from typing import Any, Callable, NoReturn
from logger import Logger
from singleton import SingletonABCMeta

class Parser(metaclass=SingletonABCMeta):
	logger = Logger.get_instance()

	# Children classes expand these and implicitly use them (in _validate_values)
	# when parsing a file

	mandatory_properties = ()

	optional_properties: dict[str, int] = {}

	type_parsers: dict[str, Callable[[str], Any]]= {}
	
	# return false if the check fails, true otherwise
	range_validators: dict[str, Callable[[Any], bool]] = {}

	# intra rules expressed as lambdas producing (bool, message)
	# if "bool" is True then crash reporting "message"
	intra_rules: list[Callable[[dict], tuple[bool, str]]] = []

	
	@staticmethod
	def _check_range(value: int, min_value: int, max_value: int) -> bool:
		return min_value <= value <= max_value

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
			self.logger.simply_v_crash(f"Value error: {e.args} in {file_name}.")
		except Exception as e:
			self.logger.simply_v_crash(f"Unexpected error parsing {file_name}: {e}")
