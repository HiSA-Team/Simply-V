# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This class represents the basic element of the
# busses and peripherals tree.

# it's the base class common to both peripherals and busses
# and is a wrapper of the address ranges assigned to the particular node
# (asgn_addr_ranges).
# Node contains all the main "NAMEs" used to identify a peripheral or a bus in a particular context
# here is an example to explain the meaning of the parameters.
# Assume we're creating a Node (Peripheral or Bus doesn't matter)
# for example "TIM_1" with 2 address ranges assigned to it:

# BASE_NAME (in this case “TIM”) it's useful to understand the type of “Node”, in this case a peripheral Timer.

# FULL_NAME (in this case “TIM_1”) it's the name we specified in the .csv, is useful to verify
# whether in the system’s “global” configuration, there are actually two nodes mistakenly expressed with the same name.

# RANGE_NAME(s) (in this case “TIM_1_range_0” and “TIM_1_range_1”; if there is only one range RANGE_NAME
# it is set equal to FULL_NAME ) are useful to have more granular control over the address space
# especially regarding the “REACHABILITY” property of an address space 
# (i.e., which bus can actually address that space, also considering LOOPBACK).
# RANGE_NAME(s) are contained inside the "Addr_Range" objects wrapped in the "asgn_addr_ranges" of a node.

# These names convention are enforced by the "Factory" hierarchy that is the centralized point
# of construction of peripherals and busses


from abc import ABC
from .addr_range import Addr_Ranges

class Node(ABC):
	def __init__(self, base_name: str, asgn_addr_ranges: Addr_Ranges, clock_domain: str, clock_frequency: int):
		self.asgn_addr_ranges = asgn_addr_ranges
		self.BASE_NAME = base_name
		self.FULL_NAME = asgn_addr_ranges.FULL_NAME
		self.CLOCK_DOMAIN: str = clock_domain
		self.CLOCK_FREQUENCY: int = clock_frequency

	def __str__(self):
		return (f"Node(BASE_NAME='{self.BASE_NAME}', FULL_NAME='{self.FULL_NAME}', "
                f"CLOCK_DOMAIN='{self.CLOCK_DOMAIN}', CLOCK_FREQUENCY={self.CLOCK_FREQUENCY}, "
                f"asgn_addr_ranges={self.asgn_addr_ranges})")

	def get_base_addr(self):
		return self.asgn_addr_ranges.get_base_addr()

	def get_end_addr(self):
		return self.asgn_addr_ranges.get_end_addr()

	def split_addr_ranges(self):
		return self.asgn_addr_ranges.split_addr_ranges()
