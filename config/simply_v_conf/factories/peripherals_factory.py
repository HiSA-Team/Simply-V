# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the Factory specialization class used to create peripherals, 
# in addition to enforcing naming convention like the buses factory it also
# checks for DDR channels and HBM support based on the particular board used in
# the configuration

from .factory import Factory 
from peripherals.peripheral import Peripheral
from peripherals.tim import Timer
from peripherals.uart import Uart
from peripherals.hbm import HBM 
from peripherals.gpioin import GPIO_in
from peripherals.gpioout import GPIO_out
from peripherals.ddr4 import DDR4
from peripherals.bram import Bram
from peripherals.debug_module import Debug_Module
from peripherals.hls import HLS
from peripherals.plic import PLIC
from peripherals.cdma import CDMA
from general.addr_range import Addr_Ranges
from general.error import Unsupported_Value_Error, Conflict_Error

class Peripherals_Factory(Factory):
	
	# Peripherals_Factory constructor
	def __init__(self):
		super().__init__()
		# Initialize the board dependent params
		self.DDR_CHANNELS: list[int] = self.env.get_supp_ddr_chs()
		self.HBM_SUPPORTED: bool = self.env.get_supp_hbm()
		self.MBUS_DDR4_LEGAL_CHANNELS: tuple
		self.HBUS_DDR4_LEGAL_CHANNELS: tuple
		# Base name to Class object MAPPING
		self.SUPPORTED_PERIPHERALS = {
			"TIM":        Timer,
			"DDR4CH":     DDR4,
			"GPIOOUT":    GPIO_out,
			"GPIOIN":     GPIO_in,
			"UART":       Uart,
			"BRAM":       Bram,
			"DMMEM":      Debug_Module,
			"PLIC":       PLIC,
			"HLSCONTROL": HLS,
			"CDMA":       CDMA,
			"HBM":        HBM,
		}

	# Extract DDR4 channel number (assuming the format is something like DDR4_CH_0)
	def _extract_ddr4_channel(self, full_name: str) -> int:
		return int(full_name.split("_")[-1])

	def set_ddr4_legal_channels(self, bus_name: str, legal_channels: tuple):
		if(bus_name == "MBUS"):
			self.MBUS_DDR4_LEGAL_CHANNELS = legal_channels
		elif(bus_name == "HBUS"):
			self.HBUS_DDR4_LEGAL_CHANNELS = legal_channels
		else:
			assert False, f"Bus {bus_name} doesn't support ddr4 channels {legal_channels}" 

	# Create peripherals extracting base name from full name and clock frequency from clock domain.
	# In case of DDR4 or HBM also enforces checks based on the board.
	# This function checks for duplicated peripherals creation
	def create_peripheral(self, full_name: str, base_addr: list[int], addr_width: list[int], 
					   clock_domain: str, bus_name: str) -> Peripheral:
		
		# register creation to check for duplicates
		self._register_creation(full_name)

		# extract informations and create "Addr_Ranges" to inject in the peripheral object
		clock_frequency = self.extract_clock_frequency(clock_domain)
		base_name = self._extract_base_name(full_name)
		id = self._extract_id(full_name)
		addr_ranges = Addr_Ranges(full_name, base_addr, addr_width)

		# Check if peripheral is supported
		if(base_name not in self.SUPPORTED_PERIPHERALS):
			raise Unsupported_Value_Error("BASE_NAME", base_name, list(self.SUPPORTED_PERIPHERALS.keys()))

		cls = self.SUPPORTED_PERIPHERALS[base_name]

		# Specialized validation logic
		if base_name == "DDR4CH":
			# for ddr the id is the channel number
			channel = id

			if channel not in self.DDR_CHANNELS:
				raise Conflict_Error("DDR4CH", "BOARD", f"Channels supported {self.DDR_CHANNELS}")

			# MBUS and HBUS only support particular DDR4 channels, so enforce the check
			if bus_name == "MBUS" and channel not in self.MBUS_DDR4_LEGAL_CHANNELS:
				raise Unsupported_Value_Error("MBUS DDR4CH", channel, self.MBUS_DDR4_LEGAL_CHANNELS)

			if bus_name == "HBUS" and channel not in self.HBUS_DDR4_LEGAL_CHANNELS:
				raise Unsupported_Value_Error("HBUS DDR4CH", channel, self.HBUS_DDR4_LEGAL_CHANNELS)

			return cls(base_name, addr_ranges, clock_domain, channel, bus_name)

		if base_name == "HBM":
			if not self.HBM_SUPPORTED:
				raise Conflict_Error("HBM", "BOARD", f"HBM supported = {self.HBM_SUPPORTED}")

		# Default construction path
		return cls(base_name, addr_ranges, clock_domain, clock_frequency)

