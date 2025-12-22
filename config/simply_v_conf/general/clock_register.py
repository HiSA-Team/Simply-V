from general.env import Env

class Clocks_Register():
	env = Env.get_instance()

	def __init__(self):
		self.clock_domains = set()
		self.clock_domains.update(self.env.get_def_clock_domains())
	
	def register_domain(self, name: str):
		self.clock_domains.add(name)
	
	def check_registered(self, domain: str) -> bool:
		return domain in self.clock_domains
