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
							clock_domain: list[str]) -> Peripheral:

		base_name = self._extract_base_name(range_name)

		addr_ranges_list = self._create_addr_ranges(base_name, range_name, base_addr, addr_width, clock_domain)

		match base_name:
			case "TIM":
				return Timer(addr_ranges_list)
			case "DDR4":
				return DDR4(addr_ranges_list)
			case "GPIOOUT":
				return GPIO_out(addr_ranges_list)
			case "GPIOIN":
				return GPIO_in(addr_ranges_list)
			case "UART":
				return Uart(addr_ranges_list)
			case "BRAM":
				return Bram(addr_ranges_list)
			case "DM":
				return Debug_Module(addr_ranges_list)
			case "PLIC":
				return PLIC(addr_ranges_list)
			case "HLS":
				return HLS(addr_ranges_list)
			case _:
				self.logger.simply_v_crash(f"Unsupported peripheral {range_name}")
