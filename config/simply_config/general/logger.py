# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This class is just a wrapper on the python logging library
# at the moment the logger is really simple but the logic is all centralized
# here in order to avoid changing the rest of the code of the application in case
# of future changes

import logging
import sys
from .singleton import Singleton

class Logger(metaclass=Singleton):
	def __init__(self):
		self.logger = logging.getLogger("Simply_V")
		self.logger.setLevel(logging.INFO)

		if not self.logger.handlers:
			formatter = logging.Formatter("%(levelname)s: %(message)s")

			# Handler for stdout: INFO and WARNING
			stdout_handler = logging.StreamHandler(sys.stdout)
			stdout_handler.setLevel(logging.INFO)
			stdout_handler.addFilter(lambda record: record.levelno < logging.ERROR)
			stdout_handler.setFormatter(formatter)

			# Handler for stderr: ERROR only
			stderr_handler = logging.StreamHandler(sys.stderr)
			stderr_handler.setLevel(logging.ERROR)
			stderr_handler.setFormatter(formatter)

			self.logger.addHandler(stdout_handler)
			self.logger.addHandler(stderr_handler)


	def simplyv_error(self, message: str):
		self.logger.error(f"--- [SIMPLY-CONFIG] {message} ---")

	def simplyv_warning(self, message: str):
		self.logger.warning(f"--- [SIMPLY-CONFIG] {message} ---")

	def simplyv_crash(self, message: str):
		self.logger.error(f"--- [SIMPLY-CONFIG] {message} ---")
		exit(1)

	def simplyv_info(self, message: str):
		self.logger.info(f"--- [SIMPLY-CONFIG] {message} ---")
