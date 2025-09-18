import pandas as pd
import logging

class Logger():
	def __init__(self, file_name: str):
		self.file_name = file_name

	def simply_v_crash(self, message: str):
		logging.error(f"[{self.file_name}]")
		logging.error(message)
		exit(1)


