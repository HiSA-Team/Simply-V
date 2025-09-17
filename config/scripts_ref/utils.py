def parse_csv(file_name: str) -> dict:
	try:
		data_set = pd.read_csv(file_name, sep=",")
		return dict(zip(data_set["Property"], data_set["Value"]))
	except (FileNotFoundError, ParserError, Exception) as e:
        messages = {
            FileNotFoundError: f"File {file_name} not found",
            ParserError: f"Malformed format in {file_name}"
        }
        logging.error(messages.get(type(e), f"Unexpected error with {file_name}"))
        exit(1)
