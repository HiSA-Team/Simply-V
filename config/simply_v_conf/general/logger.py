# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This class is just a wrapper on the python logging library
# at the moment the logger is really simple but the logic is all centralized
# here in order to avoid changing the rest of the code of the application in case
# of future changes

import logging
from .singleton import Singleton

class Logger(metaclass=Singleton):
	def __init__(self):
		self.logger = logging.getLogger("Simply_V")
		self.logger.setLevel(logging.INFO)

		if not self.logger.handlers:
			handler = logging.StreamHandler()
			handler.setFormatter(logging.Formatter("%(levelname)s: %(message)s"))
			self.logger.addHandler(handler)
	
	def simply_v_error(self, message: str):
		self.logger.error(message)

	def simply_v_warning(self, message: str):
		self.logger.warning(message)

	def simply_v_crash(self, message: str):
		self.logger.error(message)
		exit(1)

	def simply_v_info(self, message: str):
		self.logger.info(f"---{message}---")
