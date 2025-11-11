from logger import Logger
from factory import Factory
from peripherals.peripheral import Peripheral
from peripherals.tim import Timer
from peripherals.uart import Uart
from peripherals.gpioin import GPIO_in
from peripherals.gpioout import GPIO_out
from peripherals.ddr4 import DDR4
from peripherals.bram import Bram
from peripherals.debug_module import Debug_Module
from peripherals.hls import HLS
from peripherals.plic import PLIC

class Peripherals_Factory(Factory):
	def __init__(self, logger: Logger):
		super().__init__(logger)

	def create_peripheral(self, range_name: str, addr_ranges: int, \
						  range_base_addr: list[int], \
						  range_addr_width: list[int], \
						  range_clock_domain: str) -> Peripheral:

		base_name = self.extract_base_name(range_name)

		match base_name:
			case "TIM":
				return Timer(range_name, base_name, addr_ranges, range_base_addr, range_addr_width, range_clock_domain)
			case "DDR4":
				return DDR4(range_name, base_name, addr_ranges, range_base_addr, range_addr_width, range_clock_domain)
			case "GPIOOUT":
				return GPIO_out(range_name, base_name, addr_ranges, range_base_addr, range_addr_width, range_clock_domain)
			case "GPIOIN":
				return GPIO_in(range_name, base_name, addr_ranges, range_base_addr, range_addr_width, range_clock_domain)
			case "UART":
				return Uart(range_name, base_name, addr_ranges, range_base_addr, range_addr_width, range_clock_domain)
			case "BRAM":
				return Bram(range_name, base_name, addr_ranges, range_base_addr, range_addr_width, range_clock_domain)
			case "DM":
				return Debug_Module(range_name, base_name, addr_ranges, range_base_addr, range_addr_width, range_clock_domain)
			case "PLIC":
				return PLIC(range_name, base_name, addr_ranges, range_base_addr, range_addr_width, range_clock_domain)
			case "HLS":
				return HLS(range_name, base_name, addr_ranges, range_base_addr, range_addr_width, range_clock_domain)
			case _:
				self.logger.simply_v_crash(f"Unsupported peripheral {range_name}")

		 
