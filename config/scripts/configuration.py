# Author: Stefano Toscano <stefa.toscano@studenti.unina.it>
# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
# Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
# Description: Declaration of wrapper class for configuration properties with their default values (if any). Lists are just initialized as empty.

# to print logging and error messages in the shell
import logging

# Wrapper class for configuration properties
class Configuration:
	def __init__(self):
		self.CONFIG_NAME         : str = "" # The name of the bus, used in check sanity
		self.SUPPORTED_CORES	 : list = ["CORE_PICORV32", "CORE_CV32E40P", "CORE_IBEX", "CORE_MICROBLAZEV_RV32",
                                  "CORE_MICROBLAZEV_RV64", "CORE_CV64A6"]
		self.CORE_SELECTOR		 : str = ""		# (Mandatory) No default core
		self.VIO_RESETN_DEFAULT	 : int = 1      # Reset using Xilinx VIO
		self.PROTOCOL			 : str = ""		# AXI PROTOCOL used, use "MOCK" to skip checks
		self.XLEN                : int = 32		# MBUS, CPU and Toolchain data width
		self.PHYSICAL_ADDR_WIDTH : int = 32 	# MBUS physical address width
		self.CONNECTIVITY_MODE	 : str = "SAMD"	# Crossbar Configuration, Shared-Address/Multiple-Data(SAMD) or Shared-Address/Shared-Data(SASD)
		self.ADDR_WIDTH			 : int = 32 	# Address Width
		self.DATA_WIDTH			 : int = 32 	# Data Width
		self.ID_WIDTH			 : int = 4		# ID Data Width for MI and SI (a subset of it is used by the Interfaces Thread IDs)
		self.NUM_MI				 : int = 0 		# Master Interface (MI) Number
		self.NUM_SI				 : int = 0 		# Slave Interface (SI) Number
		self.MASTER_NAMES        : list = []    # List of names of masters connected to the bus
		self.RANGE_NAMES         : list = []    # List of names of slaves connected to the bus
		self.ADDR_RANGES		 : list = 1 	# Number of Address Ranges for all MI
		self.BASE_ADDR			 : list = [] 	# the Base Address of each Range of each Master
		self.RANGE_ADDR_WIDTH	 : list = [] 	# the width of each Range of each Master
		self.READ_CONNECTIVITY	 : list = [] 	# the enable option for each MI_to_SI possible Connection for Read Operations
		self.WRITE_CONNECTIVITY	 : list = [] 	# the enable option for each MI_to_SI possible Connection for Write Operations
		self.STRATEGY			 : int = 0 		# Implementation strategy, Minimize Area (1), Maximize Performance (2)
		self.R_REGISTER			 : int = 0 		# Internal Registers division
		self.Slave_Priorities	 : list = [] 	# Scheduling Priority for each Slave
		self.SI_READ_ACCEPTANCE	 : list = [] 	# Number of possible Active Read Transaction at the same time for each Slave
		self.SI_WRITE_ACCEPTANCE : list = [] 	# Number of possible Active Write Transaction at the same time for each Slave
		self.THREAD_ID_WIDTH	 : list = [] 	# Number of ID bits used by each SI for thei respective Threads
		self.SINGLE_THREAD		 : list = [] 	# Enable options for each SI in regards to the Single Thread Option
		self.BASE_ID			 : list = [] 	# Base ID for each SI
		self.MI_READ_ISSUING	 : list = [] 	# Number of possible Active Read Transaction at the same time for each Master
		self.MI_WRITE_ISSUING    : list = [] 	# Number of possible Active Write Transaction at the same time for each Master
		self.SECURE				 : list = [] 	# Master SECURE mode
		self.AWUSER_WIDTH		 : int = 0		# AXI AW User width
		self.ARUSER_WIDTH		 : int = 0		# AXI AR User width
		self.WUSER_WIDTH		 : int = 0		# AXI  W User width
		self.RUSER_WIDTH		 : int = 0		# AXI  R User width
		self.BUSER_WIDTH		 : int = 0		# AXI  B User width
		self.MAIN_CLOCK_DOMAIN   : int = 100    # Core + mbus clock domain (the main clock domain)
		self.RANGE_CLOCK_DOMAINS       : list = []    # MBUS slaves clock domains

	###########
	# Setters #
	###########
	# When XLEN parameter is parsed, ADDR_WIDTH and DATA_WIDTH are assigned accordingly

	def set_ADDR_WIDTH (self, value: int):
		# Reads the Address Widdth applied to all Interfaces
		# [AXI4 ; AXI3] => the range of possible values is (12..64)
		# AXI4LITE => the range of possible values is (1..64)
		# 32 is the default value in every scenario
		# If the value is missing or is incorrect in the csv file,  default value is used
		if ((self.PROTOCOL == "AXI4LITE") and (value in range(1, 65))):
			self.ADDR_WIDTH = value
		elif (((self.PROTOCOL == "AXI4") or (self.PROTOCOL == "AXI3")) and (value in range(12, 65))):
			self.ADDR_WIDTH = value
		elif self.PROTOCOL == "DISABLE":
			# Skip mock buses
			return
		else:
			# TODO127: Defaulting breaks multiple things in the current flow. It MUST be refactored.
			# For now, we just raise the warning, and leave the user with the selected value.
			self.ADDR_WIDTH = value
			logging.warning("Address Width value isn't compatible with AXI PROTOCOL Used. Using the user value, beware of this.")

	def set_DATA_WIDTH (self, value: int):
		# Reads the Address Widdth applied to all Interfaces
		# [AXI4 ; AXI3] => the range of possible values is {32 ,  64 ,  128 ,  256 ,  512 ,  1024}
		# AXI4LITE => the range of possible values is {32 ,  64}
		# 32 is the default value in every scenario
		# If the value is missing or is incorrect in the csv file,  default value is used
		DATA_WIDTH_Found = False
		Base_Data = 32
		while ((DATA_WIDTH_Found == False) and (Base_Data <= 1024)):
			if (value == Base_Data):
				DATA_WIDTH_Found = True
			Base_Data = Base_Data * 2
		if ((self.PROTOCOL == "AXI4LITE") and ((value == 32) or (value == 64))):
			self.DATA_WIDTH = value
		elif (((self.PROTOCOL == "AXI4") or (self.PROTOCOL == "AXI3")) and (DATA_WIDTH_Found == True)):
			self.DATA_WIDTH = value
		else:
			# TODO127: Defaulting breaks multiple things in the current flow. It MUST be refactored.
			# For now, we just raise the warning, and leave the user with the selected value.
			logging.warning("Address Width value isn't compatible with AXI PROTOCOL Used. Using the user value, beware of this.")


