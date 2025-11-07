# Author: Stefano Toscano <stefa.toscano@studenti.unina.it>
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description: this script calls the functions used to read and set configuration parameters
# according to the given Parameter that has to be set. The Configuration class is taken as input and given to the called functions to modify the Configuration.

###################
# Import packages #
###################
import logging
# Contains all the operations to set the config Parameters according to provided csv config file
from parse_properties_impl import *

def parse_property (
		config,
		property_name : str,
		property_value: str,
	):

	# Whether to skip function call
	skip_call = False

	# Skip for emtpy strings or lists
	if (property_value == []):
		skip_call = True

	# Compose function name
	base_func_name = "parse_"
	base_args = "config, property_name, property_value"
	additional_args = ""
	function_call = ""

	# Select target function and arguments
	match property_name:
		# SI and MI Number Acquisition
		case "NUM_SI" | "NUM_MI":
			func_name = base_func_name + "Interfaces"
		# CORE_SELECTOR, STRATEGY, R_REGISTER, PROTOCOL, XLEN, Connectivity Mode Acquisition,
		# Slave Priorities, Slave Thread IDs Width, Slave Single Thread Modes, Slave Base IDs,
		# Master SECURE Modes, Ranges' Base Address, Ranges' Width Acquisition
		case "CORE_SELECTOR" | "VIO_RESETN_DEFAULT" | "XLEN" | "PHYSICAL_ADDR_WIDTH" | "STRATEGY" | "R_REGISTER" | "PROTOCOL" | "CONNECTIVITY_MODE" | \
			"Slave_Priority" | "THREAD_ID_WIDTH" | "SINGLE_THREAD" | "BASE_ID" | "SECURE" | "RANGE_BASE_ADDR" | "RANGE_ADDR_WIDTH" | "RANGE_NAMES" | "MASTER_NAMES" | \
			"MAIN_CLOCK_DOMAIN" | "RANGE_CLOCK_DOMAINS":
			func_name = base_func_name + property_name

		# ID Width Acquisition
		case "ID_WIDTH":
			func_name = base_func_name + "IDWidth_UsersWidth_AddrRanges"
			additional_args = "1, 32"
		# User Widths Acquisition
		case "AWUSER_WIDTH" | "ARUSER_WIDTH" | "WUSER_WIDTH" | "RUSER_WIDTH" | "BUSER_WIDTH":
			func_name = base_func_name + "IDWidth_UsersWidth_AddrRanges"
			additional_args = "0, 1024"
		# Address Ranges Acquisition
		case "ADDR_RANGES":
			func_name = base_func_name + "IDWidth_UsersWidth_AddrRanges"
			additional_args = "1, 16"
		case "SI_READ_ACCEPTANCE" | "SI_WRITE_ACCEPTANCE":
		# Slave Read and Write Acceptance Acquisition
			func_name = base_func_name + "Acceptance"
		# Master Read and Write Acquisition
		case "MI_READ_ISSUING" | "MI_WRITE_ISSUING":
			func_name = base_func_name + "Issuing"
		# Read and Write Connectivity Acquisition
		case "READ_CONNECTIVITY" | "WRITE_CONNECTIVITY":
			func_name = base_func_name + "Connectivity"
		# Unsupported Parameters
		case _:
			skip_call = True
			logging.warning("Unsupported property " + property_name)

	# Call function
	if not skip_call:
		function_call = func_name + "(" + base_args + ", " + additional_args + ")"
		# print("[DEBUG] Calling "+ function_call)
		config = eval(function_call)

	# Return updated configuration
	return config

