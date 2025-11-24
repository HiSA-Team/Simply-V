from pprint import pprint
from factories.factory import Factory
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

	def create_peripheral(self, range_name: str, base_addr: list[int], addr_width: list[int], 
							clock_domain: str) -> Peripheral:

		base_name = self._extract_base_name(range_name)

		clock_frequency = self._extract_clock_frequency(clock_domain)

		addr_ranges_list = self.create_addr_ranges(base_name, range_name, base_addr, addr_width)

		match base_name:
			case "TIM":
				return Timer(range_name, addr_ranges_list, clock_domain, clock_frequency)
			case "DDR4":
				return DDR4(range_name, addr_ranges_list, clock_domain, clock_frequency)
			case "GPIOOUT":
				return GPIO_out(range_name, addr_ranges_list, clock_domain, clock_frequency)
			case "GPIOIN":
				return GPIO_in(range_name, addr_ranges_list, clock_domain, clock_frequency)
			case "UART":
				return Uart(range_name, addr_ranges_list, clock_domain, clock_frequency)
			case "BRAM":
				return Bram(range_name, addr_ranges_list, clock_domain, clock_frequency)
			case "DM":
				return Debug_Module(range_name, addr_ranges_list, clock_domain, clock_frequency)
			case "PLIC":
				return PLIC(range_name, addr_ranges_list, clock_domain, clock_frequency)
			case "HLS":
				return HLS(range_name, addr_ranges_list, clock_domain, clock_frequency)
			case _:
				self.logger.simply_v_crash(f"Unsupported peripheral {range_name}")
