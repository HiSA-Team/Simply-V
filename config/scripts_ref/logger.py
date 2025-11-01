import pandas as pd
import logging

class Logger():
	def __init__(self, file_name: str):
		self.file_name: str = file_name
	
	def simply_v_warning(self, message: str):
		logging.warning(message+"\n")

	def simply_v_crash(self, message: str):
		logging.error(f"[{self.file_name}] \n---{message}---\n")
		exit(1)
	
	def simply_v_info(self, message: str):
		logging.info(f"[{self.file_name}] \n---{message}---\n")


