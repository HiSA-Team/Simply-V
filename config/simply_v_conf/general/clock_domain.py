from .addr_range import Addr_Range

class Clock_Domain():
	def __init__(self, Nodes: list[Addr_Range]):
		self.CLOCK_DOMAINS = {}

		#Initialize clock domains as dictionary of CLOCK_DOMAIN -> [Nodes]
		for node in Nodes:
			if(node.CLOCK_DOMAIN not in self.CLOCK_DOMAINS):
				self.CLOCK_DOMAINS[node.CLOCK_DOMAIN] = []

			self.CLOCK_DOMAINS[node.CLOCK_DOMAIN].append(node)
	
	def is_in_domain(self, name: str, domain: str) -> bool:
		for node in self.CLOCK_DOMAINS[domain]:
			if(node.BASE_NAME == name):
				return True

		return False
		
