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

class Peripherals_Factory(Factory):
	
	# Peripherals_Factory constructor
	def __init__(self):
		super().__init__()
		# Initialize the board dependent params
		self.DDR_CHANNELS: list[int] = self.env.get_supp_ddr_chs()
		self.HBM_SUPPORTED: bool = self.env.get_supp_hbm()
		self.MBUS_DDR4_LEGAL_CHANNELS: tuple
		self.HBUS_DDR4_LEGAL_CHANNELS: tuple

	# Extract DDR4 channel number (assuming the format is something like DDR4_CH_0)
	def _extract_ddr4_channel(self, full_name: str) -> int:
		return int(full_name.split("_")[-1])

	def set_ddr4_legal_channels(self, bus_name: str, legal_channels: tuple):
		if(bus_name == "MBUS"):
			self.MBUS_DDR4_LEGAL_CHANNELS = legal_channels
		elif(bus_name == "HBUS"):
			self.HBUS_DDR4_LEGAL_CHANNELS = legal_channels
		else:
			raise ValueError(f"Bus {bus_name} doesn't support ddr4 channels {legal_channels}")

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

		# Create concrete peripheral
		match base_name:
			case "TIM":
				return Timer(base_name, addr_ranges, clock_domain, clock_frequency)
			case "DDR4CH":
				# for ddr the id is the channel number
				channel = id
				if channel not in self.DDR_CHANNELS:
					raise ValueError("Unsupported DDR4 channel for the current board configuration")
				# MBUS and HBUS only support particular DDR4 channels, so enforce the check
				if(bus_name == "MBUS") and (channel not in self.MBUS_DDR4_LEGAL_CHANNELS):
					raise ValueError(f"DDR4CH_{channel} was configured on MBUS that only supports "
									 f"channels {self.MBUS_DDR4_LEGAL_CHANNELS}")

				if(bus_name == "HBUS") and (channel not in self.HBUS_DDR4_LEGAL_CHANNELS):
					raise ValueError(f"DDR4CH_{channel} was configured on HBUS that only supports "
									 f"channels {self.HBUS_DDR4_LEGAL_CHANNELS}")
				return DDR4(base_name, addr_ranges, clock_domain, channel, bus_name)
			case "GPIOOUT":
				return GPIO_out(base_name, addr_ranges, clock_domain, clock_frequency)
			case "GPIOIN":
				return GPIO_in(base_name, addr_ranges, clock_domain, clock_frequency)
			case "UART":
				return Uart(base_name, addr_ranges, clock_domain, clock_frequency)
			case "BRAM":
				return Bram(base_name, addr_ranges, clock_domain, clock_frequency)
			case "DMMEM":
				return Debug_Module(base_name, addr_ranges, clock_domain, clock_frequency)
			case "PLIC":
				return PLIC(base_name, addr_ranges, clock_domain, clock_frequency)
			case "HLSCONTROL":
				return HLS(base_name, addr_ranges, clock_domain, clock_frequency)
			case "CDMA":
				return CDMA(base_name, addr_ranges, clock_domain, clock_frequency)
			case "HBM":
				if not self.HBM_SUPPORTED:
					raise ValueError("Unsupported HBM for the current board configuration")
				return HBM(base_name, addr_ranges, clock_domain, clock_frequency)
			case _:
				raise ValueError(f"Unsupported peripheral {full_name}")
