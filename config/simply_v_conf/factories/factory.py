# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: This is the base abstract class "Factory" from which other specific
# factories (peripherals_factory and buses_factory) derives
# it is intended to be more as a central point of creation of objects to enforce
# all the naming conventions and general checks based on "Node(s)" names
# rather than an "idiomatic" factory method design pattern, in which there is
# a concrete factory implementation for each concrete object to create, since
# the creation logic right now is still simple.
# Keep in mind that all the factories as defined are singletons, so they share
# the same state, this is used to enforce "global" checks like
# ensuring that there aren't some peripherals/buses with the same "FULL_NAME"
# somewhere in the configuration because all the factories keep track of each object
# created in the "ALREADY_CREATED" variable and are able to spot duplicated names
# in the configuration
# names MUST adhere the following syntax "{BASE_NAME}_{id}" where "{id} is a number.
# In the case of absence of multiple instances with the same "BASE_NAME"
# {id} can be omitted. "BASE_NAME" MUST contain only alphanumerics


import re
from typing import NoReturn
from general.singleton import SingletonABCMeta
from general.env import Env

class Factory(metaclass=SingletonABCMeta):
	env = Env.get_instance()
	
	# Factory constructor
	def __init__(self):
		# used to enforce no duplicate nodes
		self.ALREADY_CREATED = set()

	# Private functions used from derived classes
	
	# Function used to register the creation of every node so that duplicate "FULL_NAMEs"
	# can be spotted
	def _register_creation(self, full_name: str) -> None:
		if(full_name in self.ALREADY_CREATED):
			raise ValueError(f"There are multiple nodes with the same full name ({full_name})")

		self.ALREADY_CREATED.add(full_name)

	# Function used to extract the BASENAME from a FULLNAME enforcing the same naming convention
	# for each node
	def _extract_base_name(self, full_name: str) -> str:
		return full_name.split("_")[0].upper()
	

	def _extract_id(self, full_name: str) -> int | None:
		tmp_name = full_name.split("_")
		id = None
		try:
			if (len(tmp_name) == 2):
				id = int(tmp_name[1])
			# Erroneous use of "_" in the BASENAME part of the name
			if (len(tmp_name) > 2):
				raise Exception
		except:
			raise ValueError(f"There is something wrong with {full_name} format name (BASENAME_id format enforced)")
		
		return id

	# Function used to extract the clock frequency value from a clock domain name enforcing the same naming convention
	# for each clock domain
	def extract_clock_frequency(self, clock_domain: str) -> int | NoReturn:
		try:
			return int(clock_domain.split("_")[-1])
		except ValueError:
			raise ValueError(f"There is something wrong with {clock_domain} format name")
