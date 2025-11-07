# Author: Stefano Toscano <stefa.toscano@studenti.unina.it>
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description: Definitions of the property-specific parsing functions and checking constraint.
#			  If constraints aren't respected, correct values are used, issuing a warning and ignoring the input.

###################
# Import packages #
###################
# to print logging and error messages in the shell
import logging
# for math operations
import math
# configuration Class declaration
from configuration import *
# Valid protocols
from check_config import VALID_PROTOCOLS

def parse_CORE_SELECTOR (
		config,
		property_name : str,
		property_value: str,
	):
	value = str(property_value)
	config.CORE_SELECTOR = value

	return config

def parse_VIO_RESETN_DEFAULT (
		config,
		property_name : str,
		property_value: str,
	):

	value = int(property_value)
	config.VIO_RESETN_DEFAULT = value
	return config

def parse_Interfaces (
		config,
		property_name : str,
		property_value: str,
	):
	# Reads the number of Master and Slave Interfaces
	# The range of possible values is (0..16) whith 1 as deafault value
	# If the value is missing or is incorrect in the csv file,  default value is used
	value = int(property_value)
	if (value in range(0, 17)):
		match property_name :
			case "NUM_SI":
				config.NUM_SI = value
				# Assert PBUS has only one master
				if ( config.CONFIG_NAME == "PBUS" ) and ( value != 1 ):
					logging.error(property_name  + " must be 1 for PBUS, not " + str(value))
					exit(1)
			case "NUM_MI":
				config.NUM_MI = value
	else:
		logging.warning(property_name  + " out-of-range (0..16). Using default value.")

	return config

def parse_STRATEGY (
		config,
		property_name : str,
		property_value: str,
	):
	# Reads the configuration STRATEGY
	# The range of possible values is [0 ; 2] whith 0 as deafault value
	# 0 => Use configuration STRATEGY in the Connectivity Mode property_name
	# 1 => SASD
	# 2 => SAMD
	# If the value is missing or is incorrect in the csv file,  default value is used
	value = int(property_value)
	if (value in range(0, 3)):
		config.STRATEGY = value
	else:
		logging.warning("STRATEGY out-of-range [0 ; 2]. Using default value.")
	return config

def parse_R_REGISTER (
		config,
		property_name : str,
		property_value: str,
	):
	# Reads the R_REGISTER value
	# The range of possible values is (0, 1) whith 0 as deafault value
	# 1 => only if SASD configuration STRATEGY is selected
	# If the value is missing or is incorrect in the csv file,  default or coherent value is used
	value = int(property_value)
	if (config.STRATEGY == 2):
		config.R_REGISTER = 0
		logging.warning("configuration STRATEGY set to 2. By default Connectivity Mode is SAMD and R_REGISTER is 0. input Ignored.")
	else:
		if (value in range(0, 2)):
			config.R_REGISTER = value
		else:
			logging.warning("R_REGISTER value out-of-range (0, 1). Using default value.")
	return config

def parse_PROTOCOL (
		config,
		property_name : str,
		property_value: str,
	):
	# Reads the AXI PROTOCOL Version
	# The range of possible values is (AXI4, AXI4LITE, AXI3) whith AXI4 as deafault value
	# If the value is missing or is incorrect in the csv file,  default value is used
	if property_value in VALID_PROTOCOLS:
		config.PROTOCOL = property_value
	else:
		logging.error(f"PROTOCOL {property_value} invalid.")
		exit(1)
	return config

def parse_XLEN (
		config,
		property_name : str,
		property_value: str,
):
	# No need to parse for DISABLE buses
	if (config.PROTOCOL == "DISABLE"):
		# No-op
		return config
	# Set BUS-related parameters
	match config.CONFIG_NAME:
		# Main bus, use XLEN
		case "MBUS":
			value = int(property_value)
			# Check if the XLEN value is valid
			if (value not in [32, 64]):
				logging.warning("Invalid XLEN value ({value}), please select either 32 or 64")
			# XLEN property will set bus DATA_WIDTH
			# Note: ADDR_WIDTH is set by parse PHYSICAL_ADDR_WIDTH after XLEN is parsed
			config.XLEN = value
			# Select BUS DATA_WIDTH accordingly
			config.set_DATA_WIDTH(value)
		# Peripheral Bus, fix Data Width to 32
		case "PBUS":
			config.set_DATA_WIDTH(32)
		# High-performance Bus, fix Data Width to 512
		case "HBUS":
			config.set_DATA_WIDTH(512)
		# SoC config
		case "SYS":
			# Set XLEN in order to check CORE data width correctness
			config.XLEN = int(property_value)
			logging.info("Skipping DATA_WIDTH set for SYS")
		case _:
			logging.error("Can't read valid config.CONFIG_NAME " + config.CONFIG_NAME)
			exit(1)

	return config

def parse_PHYSICAL_ADDR_WIDTH (
		config,
		property_name : str,
		property_value: str,
):

	# When parsing the Peripheral Bus, fix the Address Width to 32
	if config.CONFIG_NAME == "PBUS":
		config.PHYISICAL_ADDR_WIDTH = 32
		config.set_ADDR_WIDTH(32)
	# Otherwise parse the property
	else:
		physical_addr_width = int(property_value)
		xlen = int(config.XLEN)

		# TODO127:
		# this is removed for now, as it breaks the check_config flow.
		# It happens because checks are performed before XLEN value is correctly set
		# in some cases, hence the flow fails.

		# Physical Address Width depends on XLEN.
		# It can either be 32 for 32-bit systems, or larger for 64-bit system.
		# However, 64-bit systems might not need all 64 bits addressing space.
		#if 	((xlen == 32) and (physical_addr_width != 32)) \
		#	or \
		#	((xlen == 64) and (physical_addr_width < 32)) :
		#	logging.error("Invalid XLEN ({xlen}) and physical_addr_width ({phyisical_addr_width}) values established")
		#	exit(1)

		# Set proptery in config
		config.PHYISICAL_ADDR_WIDTH = physical_addr_width
		config.set_ADDR_WIDTH(physical_addr_width)

	return config

def parse_IDWidth_UsersWidth_AddrRanges (
		config,
		property_name : str,
		property_value: str,
	    lower_bound   : int,
		higher_bound  : int,
    ):
	# Reads the Data Width applied to all Master Interfacess
	# The range of possible values is (4..32) whith 4 as deafault value

	# Reads User Widths used by each Interface (the AXI PROTOCOL Signals)
	# The range of possible values is (0..1024) whith 0 as deafault value

	# Reads the number of Address Ranges applied to all Master Interfaces
	# The range of possible values is (1..16) whith 1 as deafault value

	# If the values are missing or are incorrect in the csv file,  default value is used
	value = int(property_value)
	if (value in range(lower_bound, higher_bound+1)):
		match property_name :
			case "ID_WIDTH":
				config.ID_WIDTH = value
			case "AWUSER_WIDTH":
				config.AWUSER_WIDTH = value
			case "ARUSER_WIDTH":
				config.ARUSER_WIDTH = value
			case "WUSER_WIDTH":
				config.WUSER_WIDTH = value
			case "RUSER_WIDTH":
				config.RUSER_WIDTH = value
			case "BUSER_WIDTH":
				config.BUSER_WIDTH = value
			case "ADDR_RANGES":
				config.ADDR_RANGES = value
	else:
		logging.warning(property_name  + " value out-of-range (" + str(lower_bound) + ".." + str(higher_bound) + "). Using default value.")
	return config

def parse_CONNECTIVITY_MODE (
		config,
		property_name : str,
		property_value: str,
	):
	# Reads the Connectivity Mode
	# The two possible values are SAMD and SASD
	# [configuration STRATEGY = 1 or R_REGISTER = 1] => SASD
	# [configuration STRATEGY = 2] => SAMD
	# If the value is missing or is incorrect in the csv file,  default or coherent value is used
	if ((config.STRATEGY == 1) or (config.R_REGISTER == 1)):
		config.CONNECTIVITY_MODE = "SASD"
		logging.warning("configuration STRATEGY or R_REGISTER set to 1. By default Connectivity Mode is SASD. input ignored.")
	elif (config.STRATEGY == 2):
		config.CONNECTIVITY_MODE = "SAMD"
		logging.warning("configuration STRATEGY set to 2. By default Connectivity Mode is SAMD. input ignored.")
	else:
		if ((property_value == "SASD") or (property_value == "SAMD")):
			config.CONNECTIVITY_MODE = property_value
		else:
			logging.warning("Connectivity Mode invalid. Using default value " + config.CONNECTIVITY_MODE + ".")
	return config

def parse_Slave_Priority (
		config,
		property_name : str,
		property_value: str,
	):
	# Reads every Slave Interface Priority
	# The range of possible values is (0..16) whith 0 (Round-Robin) as deafault value
	# If the values are missing or are incorrect in the csv file,  default value is used (input validity check is done for the single Slave)
	values = property_value.split()
	if ((len(values) == config.NUM_SI)):
		for i in range(config.NUM_SI):
			number = int(values[i])
			if (number in range(0, 17)):
				config.Slave_Priorities.append(number)
			else:
				config.Slave_Priorities.append(0)
				if (i < 10):
					logging.warning("A Priority value is out-of-range (0..16). Using default value for this Slave." + " - S0" + str(i))
				else:
					logging.warning("A Priority value is out-of-range (0..16). Using default value for this Slave." + " - S" + str(i))
	else:
		for i in range(config.NUM_SI):
			config.Slave_Priorities.append(0)
		logging.warning("Not enough Priority values have been given. Using default values.")
	return config

def parse_Acceptance (
		config,
		property_name : str,
		property_value: str,
	):
	# Reads the number of Active Read or Write Transactions that each Slave Interface can generate
	# The range of possible values is (1..32) whith 2 as deafault value
	# SASD => 1
	# If the value is missing or is incorrect in the csv file,  default or coherent value is used (input validity check is done for the single Slave)
	values = property_value.split()
	if (config.CONNECTIVITY_MODE == "SASD"):
		for i in range(config.NUM_SI):
			match property_name :
				case "SI_READ_ACCEPTANCE":
					config.SI_READ_ACCEPTANCE.append(1)
				case "SI_WRITE_ACCEPTANCE":
					config.SI_WRITE_ACCEPTANCE.append(1)
		logging.warning("Connectivity Mode set to SASD. By default every " + property_name  + " value is set to 1. input Ignored.")
	elif ((len(values) == config.NUM_SI)):
		for i in range(config.NUM_SI):
			number = int(values[i])
			if (number in range(1, 33)):
				match property_name :
					case "SI_READ_ACCEPTANCE":
						config.SI_READ_ACCEPTANCE.append(number)
					case "SI_WRITE_ACCEPTANCE":
						config.SI_WRITE_ACCEPTANCE.append(number)
			else:
				match property_name :
					case "SI_READ_ACCEPTANCE":
						config.SI_READ_ACCEPTANCE.append(2)
					case "SI_WRITE_ACCEPTANCE":
						config.SI_WRITE_ACCEPTANCE.append(2)
				si_index = ""
				if (i < 10):
					si_index = "S0" + str(i)
				else:
					si_index = "S" + str(i)
					logging.warning("A " + property_name  + " value is out-of-range (1..32). Using default value for this Slave." + " - " + si_index)
	else:
		for i in range(config.NUM_SI):
				match property_name :
					case "SI_READ_ACCEPTANCE":
						config.SI_READ_ACCEPTANCE.append(2)
					case "SI_WRITE_ACCEPTANCE":
						config.SI_WRITE_ACCEPTANCE.append(2)
		logging.warning("Not enough " + property_name  + " values have been given. Using default values.")
	return config

def parse_THREAD_ID_WIDTH (
		config,
		property_name : str,
		property_value: str,
	):
	# Reads the number of ID bits used by each Slave Interface for its Thread IDs
	# For the moment whe don't use the and these numbers are set to 0,  the default value (input validity check is done for the single Slave)
	values = property_value.split()
	Bits_Available = math.floor(config.ID_WIDTH - math.log2(config.NUM_SI))
	if (Bits_Available < 0):
		Bits_Available = 0
	Bits_Available = 0 # At the moment we don't need them
	if (Bits_Available == 0):
		for i in range(config.NUM_SI):
			config.THREAD_ID_WIDTH.append(0)
		logging.info("There are no bits available for Thread IDs. Setting all values to 0")
	elif ((len(values) == config.NUM_SI)):
		for i in range(config.NUM_SI):
			number = int(values[i])
			if (number in range(1, Bits_Available+1)):
				config.THREAD_ID_WIDTH.append(number)
			else:
				config.THREAD_ID_WIDTH.append(0)
				if (i < 10):
					logging.warning("A Thread ID value is out-of-range [0 ; Bits_Available]. Using default value for this Slave." + " - S0" + str(i))
				else:
					logging.warning("A Thread ID value is out-of-range [0 ; Bits_Available]. Using default value for this Slave." + " - S" + str(i))
	else:
		for i in range(config.NUM_SI):
			config.THREAD_ID_WIDTH.append(0)
		logging.warning("Not enough Thread IDs values have been given. Using default values.")
	return config

def parse_SINGLE_THREAD (
		config,
		property_name : str,
		property_value: str,
	):
	# Reads the Silngle Thread Mode option for each Slave Interface
	# The range of possible values is (0, 1) whith 0 as deafault value
	# 0 => Multiple Threads
	# 1 => Single Thread
	# If the value is missing or is incorrect in the csv file,  default value is used (input validity check is done for the single Slave)
	values = property_value.split()
	if ((len(values) == config.NUM_SI)):
		for i in range(config.NUM_SI):
			number = int(values[i])
			if (number in range(0, 2)):
				config.SINGLE_THREAD.append(number)
			else:
				config.SINGLE_THREAD.append(0)
				if (i < 10):
					logging.warning("A Single Thread value is out-of-range (0, 1). Using default value for this Slave." + " - S0" + str(i))
				else:
					logging.warning("A Single Thread value is out-of-range (0, 1). Using default value for this Slave." + " - S" + str(i))
	else:
		for i in range(config.NUM_SI):
			config.SINGLE_THREAD.append(0)
		logging.warning("Not enough Single Thread values have been given. Using default values.")
	return config

def parse_BASE_ID (
		config,
		property_name : str,
		property_value: str,
	):
	# Reads the 32 bit Base ID value for each Slave Interface
	# The range of possible values is [0x00000000 ; 0xffffffff] whith 0x00000000 as deafault value
	# If the value is missing or is incorrect in the csv file,  default value is used
	# It also check input format validity
	values = property_value.split()
	correct_format = True
	if ((len(values) != config.NUM_SI) or (property_value == "")):
		correct_format = False
	for i in range(config.NUM_SI):
		if (correct_format == False):
			break
		if ((len(values[i]) != 10) or (values[i][0] != "0") or (values[i][1] != "x")):
			correct_format = False
			break
		for j in range(8):
			if ((ord(values[i][j+2]) in range(48, 58)) or (ord(values[i][j+2]) in range (97, 103))):
				continue
			else:
				correct_format = False
				break
	if ((len(values) == config.NUM_SI) and (correct_format == True)):
		for i in range(config.NUM_SI):
			config.BASE_ID.append(values[i])
	else:
		for i in range(config.NUM_SI):
			config.BASE_ID.append("0x00000000")
		logging.warning("Not enough correct Base IDs values have been given. Using default values.")
	return config

def parse_Issuing (
		config,
		property_name : str,
		property_value: str,
	):
	# Reads the number of Active Read or Write Transactions that each Master Interface can generate
	# The range of possible values is (1..32) whith 4 as deafault value
	# (AXI4LITE,AXI3) => 1
	# If the value is missing or is incorrect in the csv file,  default or coherent value is used (input validity check is done for the single Master)
	values = property_value.split()

	if ((config.PROTOCOL == "AXI3") or (config.PROTOCOL == "AXI4LITE")):
		for i in range(config.NUM_MI):
			match property_name :
				case "MI_READ_ISSUING":
					config.MI_READ_ISSUING.append(1)
				case "MI_WRITE_ISSUING":
					config.MI_WRITE_ISSUING.append(1)
		logging.warning("PROTOCOL is set to " + config.PROTOCOL + ". By default every value is set to 1. input Ignored.")
	elif ((len(values) == config.NUM_MI)):
		for i in range(config.NUM_MI):
			number = int(values[i])
			if (number in range(1, 33)):
				match property_name :
					case "MI_READ_ISSUING":
						config.MI_READ_ISSUING.append(number)
					case "MI_WRITE_ISSUING":
						config.MI_WRITE_ISSUING.append(number)
			else:
				match property_name :
					case "MI_READ_ISSUING":
						config.MI_READ_ISSUING.append(4)
					case "MI_WRITE_ISSUING":
						config.MI_WRITE_ISSUING.append(4)
				if (i < 10):
					logging.warning("An " + property_name  + " value is out-of-range (1..32). Using default value for this Master." + " - M0" + str(i))
				else:
					logging.warning("An " + property_name  + " value is out-of-range (1..32). Using default value for this Master." + " - M" + str(i))
	else:
		for i in range(config.NUM_MI):
			match property_name :
				case "MI_READ_ISSUING":
					config.MI_READ_ISSUING.append(4)
				case "MI_WRITE_ISSUING":
					config.MI_WRITE_ISSUING.append(4)
		logging.warning("Not enough correct " + property_name  + " values have been given. Using default values.")
	return config

def parse_SECURE(
		config,
		property_name : str,
		property_value: str,
	):
	# Reads the TrustZone Activation option for each Master Interface
	# The range of possible values is (0, 1) whith 0 as deafault value
	# 0 => Non SECURE
	# 1 => SECURE
	# If the value is missing or is incorrect in the csv file,  default value is used (input validity check is done for the single Master)
	values = property_value.split()

	if ((len(values) == config.NUM_MI)):
		for i in range(config.NUM_MI):
			number = int(values[i])
			if (number in range(0, 2)):
				config.SECURE.append(number)
			else:
				config.SECURE.append(0)
				if (i < 10):
					logging.warning("A SECURE value is out-of-range (0, 1). Using default value for this Master." + " - M0" + str(i))
				else:
					logging.warning("A SECURE value is out-of-range (0, 1). Using default value for this Master." + " - M" + str(i))
	else:
		for i in range(config.NUM_MI):
			config.SECURE.append(0)
		logging.warning("Not enough correct SECURE values have been given. Using default values.")
	return config

def parse_RANGE_BASE_ADDR (
		config,
		property_name : str,
		property_value: str,
	):

	# No need to parse for DISABLE buses
	if (config.PROTOCOL == "DISABLE"):
		# No-op
		return config

	# Reads every up to 64-bit Range Base Address for each Master Interface
	# The range of possible values is [0x0000000000000000 ; 0xffffffffffffffff] with 0xffffffffffffffff (not used) as deafault value (0x0000000000100000 for the first Range of every Master)
	# If the value is missing or is incorrect, an error is generated

	values = property_value.split()

	# Check addresses format
	correct_format = True
	# If we have the right amount of strings
	NUM_ADDRESSES = config.NUM_MI*config.ADDR_RANGES
	if (len(values) == NUM_ADDRESSES):
		# Check each string
		for i in range(NUM_ADDRESSES):
			# Must start with 0x or 0X
			# Must be no longer than 64 bits, hence 16+2 chars
			if (
					(values[i][0] != "0") or \
	   				(values[i][1] not in {"x","X"}) or \
					(len(values[i]) > 18)
				):
				correct_format = False
				break
			# Must contain only chars in "[0-9][A-F][a-f]"
			for j in range(len(values[i])-2):
				if not ((ord(values[i][j+2]) in range(48, 58)) or (ord(values[i][j+2]) in range (97, 103))):
					correct_format = False
					break
		#
		if correct_format:
			# Save each string in config
			for i in range(config.NUM_MI):
				for j in range(config.ADDR_RANGES):
					config.BASE_ADDR.append(values[(config.ADDR_RANGES * i) + j])
		else:
			logging.error("Wrong RANGE_BASE_ADDR format.")
			exit(1)
	else:
		logging.error("Not enough correct RANGE_BASE_ADDR values.")
		exit(1)
	# Return
	return config

def parse_RANGE_ADDR_WIDTH (
		config,
		property_name : str,
		property_value: str,
	):

	# No need to parse for DISABLE buses
	if (config.PROTOCOL == "DISABLE"):
		# No-op
		return config

	# Reads every Range Address Width for each Master Interface. It must be inferior to the global Address Width
	# [AXI4 ; AXI3] => the range of possible values is (12..64) whith 0 as deafault value (12 for the first Range of every Master)
	# AXI4LITE => the range of possible values is (1..64) whith 0 as deafault value (12 for the first Range of every Master)
	# If the value is missing or is incorrect in the csv file,  default or coherent value is used (input validity check is done for the single Master)
	values = property_value.split()
	if ((len(values) == config.NUM_MI*config.ADDR_RANGES) ):
		if (config.PROTOCOL == "AXI4LITE"):
			for i in range(config.NUM_MI):
				for j in range(config.ADDR_RANGES):
					number = int(values[config.ADDR_RANGES*i+j])
					if ((number in range(1, 65)) and (number <= config.ADDR_WIDTH)):
						config.RANGE_ADDR_WIDTH.append(number)
					elif (j == 0):
						config.RANGE_ADDR_WIDTH.append(12)
						if (i < 10):
							logging.warning("A RANGE_ADDR_WIDTH value is out-of-range (1..64) or greater than global Address Width. Using default value for this Master." + " - M0" + str(i) + ",  Range " + str(j))
						else:
							logging.warning("A RANGE_ADDR_WIDTH value is out-of-range (1..64) or greater than global Address Width. Using default value for this Master." + " - M" + str(i) + ",  Range " + str(j))
					else:
						config.RANGE_ADDR_WIDTH.append(0)
						if (i < 10):
							logging.warning("A RANGE_ADDR_WIDTH value is out-of-range (1..64) or greater than global Address Width. Using default value for this Master." + " - M0" + str(i) + ",  Range " + str(j))
						else:
							logging.warning("A RANGE_ADDR_WIDTH value is out-of-range (1..64) or greater than global Address Width. Using default value for this Master." + " - M" + str(i) + ",  Range " + str(j))
		else:
			for i in range(config.NUM_MI):
				for j in range(config.ADDR_RANGES):
					number = int(values[config.ADDR_RANGES*i+j])
					if ((number in range(12, 65)) and (number <= config.ADDR_WIDTH)):
						config.RANGE_ADDR_WIDTH.append(number)
					elif (j == 0):
						config.RANGE_ADDR_WIDTH.append(12)
						if (i < 10):
							logging.warning("A RANGE_ADDR_WIDTH value is out-of-range (12..64) or greater than global Address Width. Using default value for this Master." + " - M0" + str(i) + ",  Range " + str(j))
						else:
							logging.warning("A RANGE_ADDR_WIDTH value is out-of-range (12..64) or greater than global Address Width. Using default value for this Master." + " - M" + str(i) + ",  Range " + str(j))
					else:
						config.RANGE_ADDR_WIDTH.append(0)
						if (i < 10):
							logging.warning("A RANGE_ADDR_WIDTH value is out-of-range (12..64) or greater than global Address Width. Using default value for this Master." + " - M0" + str(i) + ",  Range " + str(j))
						else:
							logging.warning("A RANGE_ADDR_WIDTH value is out-of-range (12..64) or greater than global Address Width. Using default value for this Master." + " - M" + str(i) + ",  Range " + str(j))
	else:
		logging.error("Not enough correct Range Width values have been given.")
		exit(1)
	return config

def parse_Connectivity (
		config,
		property_name : str,
		property_value: str,
	):
	# Reads the Activation option for each Master-Slave Connectione for Read or Write Transactions
	# The range of possible values is (0, 1) whith 1 as deafault value
	# 0 => Connection Activated
	# 1 => Connection Deactivated
	# If the value is missing or is incorrect in the csv file,  default value is used (input validity check is done for the single Connection)
	values = property_value.split()
	if ((len(values) == config.NUM_MI*config.NUM_SI)):
		for i in range(config.NUM_MI):
			for j in range(config.NUM_SI):
				number = int(values[config.NUM_SI*i+j])
				if (number in range(0, 2)):
					match property_name :
						case "READ_CONNECTIVITY":
							config.READ_CONNECTIVITY.append(number)
						case "WRITE_CONNECTIVITY":
							config.WRITE_CONNECTIVITY.append(number)
				else:
					match property_name :
						case "READ_CONNECTIVITY":
							config.READ_CONNECTIVITY.append(1)
						case "WRITE_CONNECTIVITY":
							config.WRITE_CONNECTIVITY.append(1)
					index = ""
					if (i < 10):
						index = " - M0" + str(i)
					else:
						index = " - M" + str(i)
					if (j < 10):
						index = index + "S0" + str(j)
					else:
						index = index + "S" + str(j)
					logging.warning("A " + property_name  + " value is out-of-range (0, 1). Using default value for this Master and Slave." + index)
	else:
		for i in range(config.NUM_MI):
			for j in range(config.NUM_SI):
				match property_name :
					case "READ_CONNECTIVITY":
						config.READ_CONNECTIVITY.append(1)
					case "WRITE_CONNECTIVITY":
						config.WRITE_CONNECTIVITY.append(1)
		logging.warning("Not enough correct " + property_name  + " values have been given. Using default values.")
	return config

def parse_RANGE_NAMES(
	config,
	property_name : str,
	property_value: str,
):
	values = property_value.split()
	config.RANGE_NAMES = values.copy()
	return config

def parse_MASTER_NAMES(
	config,
	property_name : str,
	property_value: str,
):
	values = property_value.split()
	config.MASTER_NAMES = values.copy()
	return config

def parse_MAIN_CLOCK_DOMAIN(
	config,
	property_name : str,
	property_value: str,
):
	config.MAIN_CLOCK_DOMAIN = int(property_value)
	return config

def parse_RANGE_CLOCK_DOMAINS(
	config,
	property_name : str,
	property_value: str,
):
	values = [int(prop) for prop in property_value.split()]
	config.RANGE_CLOCK_DOMAINS = values.copy()
	return config
