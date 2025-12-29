# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This file defines the uart peripheral

from general.addr_range import Addr_Ranges
from .peripheral import Peripheral
from pathlib import Path
import os
import re

class Uart(Peripheral):
	def __init__(self, base_name: str, addr_ranges_list: Addr_Ranges, clock_domain: str, clock_frequency: int):

		super().__init__(base_name, addr_ranges_list, clock_domain, clock_frequency)
		self.HAL_DRIVER = True


	def config_ip(self, root_path: str, **kwargs) -> None:
		uart_path = os.path.join(root_path, "xlnx_axi_uartlite", "config.tcl")
		config_path = Path(uart_path)

		pattern = re.compile(
			r"CONFIG\.C_S_AXI_ACLK_FREQ_HZ ?\{[0-9]+\}"
		)

		# convert frequency from MHz to Hz
		replacement = f"CONFIG.C_S_AXI_ACLK_FREQ_HZ {{{self.CLOCK_FREQUENCY}000000}}"

		content = config_path.read_text()
		content = pattern.sub(replacement, content)
		config_path.write_text(content)
