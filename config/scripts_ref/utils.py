import pandas as pd
import logging

def parse_csv(file_name: str) -> dict:
	try:
		data_set = pd.read_csv(file_name, sep=",")
		data_dict = dict(zip(data_set["Property"], data_set["Value"]))
		return data_dict
	except (FileNotFoundError, ValueError, Exception) as e:
		messages = {
			FileNotFoundError: f"File {file_name} not found",
			ValueError: f"Malformed format in {file_name}"
		}
		logging.error(messages.get(type(e), f"Unexpected error with {file_name}"))
		exit(1)
