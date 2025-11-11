import re
from logger import Logger

class Factory():
	def __init__(self, logger: Logger):
		self.logger = logger

	#Each node (peripheral or bus) that should be created, 
	#shouldn't have duplicates, so when refering to different instances of different nodes
	#(for example TIM_1 allocated on PBUS and TIM_1 allocated on MBUS)
	#calling them with the same name in the configuration (.csv) files
	#will lead to an error in the configuration flow.
	#When trying to specify different "nodes" of the same "category"
	#you MUST adhere the following syntax "BASENAME_#" where "#" is a number.
	#In the case of absence of multiple instances with the same "BASENAME"
	#"#" can be omitted.
	#The important thing is that there aren't duplicates of the same "BASENAME"
	#anywhere in the configuration, when they're clearly refering to different
	#istances of the same "BASENAME".

	def extract_base_name(self, name: str):
		pattern = re.compile(r"^(?P<prefix>[A-Za-z0-9]+)")
	
		match = pattern.match(name)
		if match:
			base_name = match.group("prefix")
			return base_name.upper() #upper just in case, to have uniform names
		else:
			self.logger.simply_v_crash(f"There is something wrong with {name} format name\n")
