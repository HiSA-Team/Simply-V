# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: The class "LeafBus_Parser" inherits from the "Bus_Parser" class, extending the checked
# properties with the ones common to all LeafBuses

from .bus_parser import Bus_Parser

class LeafBus_Parser(Bus_Parser):
	#extend the father defined data structs used for parsing/validation

	def __init__(self):
		pass
