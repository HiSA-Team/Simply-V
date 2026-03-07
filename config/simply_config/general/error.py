# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This file contains all the custom classes of error
# defined in order to:
# 1 - Having more consistent errors logs
# 2 - Facilitate system instrumentation for negative testing purposes
# The classes of errors the system manages are:
# - "R" Out-of-Range Value
# - "T" Invalid data Type
# - "U" Unsupported Value
# - "C" Conflicting configurations caused by erroneous parameters interactions
# - "M" missing parameters
# - "N" Naming convention not respected

from typing import Optional, Any

# Base class for all custom exceptions,
# gives the possibility to use
# "except SimplyV_Error" to capture all the custom Exception classes
class SimplyV_Error(Exception):
	pass

class Out_Of_Range_Error(SimplyV_Error):
	def __init__(self, param, value, min_val, max_val):
		message = f"{param} out of RANGE: {value} not in [{min_val}, {max_val}]"
		message += "[E_TYPE R]"
		super().__init__(message)

class Invalid_Type_Error(SimplyV_Error):
	def __init__(self, param, value):
		message = f"{param} has invalid TYPE: {type(value)}"
		# add error type identifier
		message += "[E_TYPE T]"

		super().__init__(message)

class Unsupported_Value_Error(SimplyV_Error):
	def __init__(self, param, value, allowed_values: Optional[list[Any] | tuple[Any]] = None,
				 details: Optional[str] = None):
		message = ""
		if details:
			message += f"{details}, "
		message += f"{param} has UNSUPPORTED value: {value}. "
		if allowed_values:
			message += f"Allowed values: {allowed_values}. "
		# add error type identifier
		message += "[E_TYPE U]"
		super().__init__(message)

class Conflict_Error(SimplyV_Error):
	def __init__(self, param_a, param_b, details: Optional[Any] = None):
		message = ""
		if details:
			message += f"{details}, "
		message += f"CONFLICTING parameters: {param_a} and {param_b} "
		# add error type identifier
		message += "[E_TYPE C]"
		super().__init__(message)

class Missing_Parameter_Error(SimplyV_Error):
	def __init__(self, params: list[str]):
		params_str = [f"{param} MISSING" for param in params]
		message = " ".join(params_str)
		# add error type identifier
		message += f"[E_TYPE M]"
		super().__init__(message)

class Naming_Convention_Error(SimplyV_Error):
	def __init__(self, param, value, expected_format):
		message = f"{param} = {value} does not respect NAMING CONVENTION: {expected_format} "
		# add error type identifier
		message += "[E_TYPE N]"
		super().__init__(message)
