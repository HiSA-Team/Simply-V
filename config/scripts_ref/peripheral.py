from node import Node

class Peripheral(Node):
	def __init__(self, name: str , assigned_addr_ranges: int, base_addr: list, addr_width: list, clock: int):
		self.NAME :str = name;
		self.LEGAL_CLOCK_DOMAIN = 0

		super().__init__(assigned_addr_ranges, base_addr, addr_width, clock)
		
