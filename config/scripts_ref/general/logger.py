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

	def simply_v_warning(self, message: str):
		self.logger.warning(message)

	def simply_v_crash(self, message: str):
		self.logger.error(message)
		exit(1)

	def simply_v_info(self, message: str):
		self.logger.info(f"---{message}---")
