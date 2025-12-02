# Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
# Description: The class "Addr_Range" models a range of addresses
# implementing all the basic functions to check ranges overlappings and containments,
# it also has the "REACHABLE_FROM" attribute that contains all the "FULL_NAME" of the
# busses that can reach that range (refer to node.py header for the definition of what a "FULL_NAME" is).
# The class "Addr_Ranges" models a list of "Addr_Range", since each node (bus or peripheral)
# can have multiple address ranges, objects of this class will be embedded in "Node" class
# exposing an uniform set of functions that a Node can use to interact with its address ranges
# independently of the number of address ranges that belong to it.
# The class "Addr_Range" should be only used internally by "Addr_Ranges" class.

# a RANGE_NAME (contained in Addr_Range objects) identifies a range of addresses rather than a single node. 
# (This enables correct handling of several edge cases, for example:
# A NonLeafBus connected in loopback that, for some reason, can only address a certain 
# address range of a peripheral connected to its parent node. 
# It is incorrect to say that the NonLeafBus addresses the peripheral “FULL_NAME”; 
# instead, it may address specific “RANGE_NAME(s)” of that peripheral. 

import re

class Addr_Range():

	# Addr_Range Constructor
	def __init__(self, range_name: str, range_base_addr: int, range_addr_width: int):
		self.RANGE_NAME: str = range_name
		self.RANGE_BASE_ADDR : int = range_base_addr 
		self.RANGE_ADDR_WIDTH : int = range_addr_width 
		
		# compute the number of consecutive least significant bits equal to 0 that we
		# get from the number obtained considering "RANGE_ADDR_WIDTH" as a power of 2 exponent
		# ex. RANGE_ADDR_WIDTH == 3 -> 2**3 = 8 -> least_significant_zeroes of 8 = 3
		least_significant_zeroes = ~(~ 1 << (self.RANGE_ADDR_WIDTH - 1) )

		#RANGE_BASE_ADDR need to have "n" consecutive least significant bits equal to 0
		if (self.RANGE_BASE_ADDR & least_significant_zeroes) != 0:
			raise ValueError(f"BASE_ADDR not compatible with RANGE_ADDR_WIDTH in {self.RANGE_NAME}")

		# RANGE_END_ADDR is the first address outside the addressable range
		self.RANGE_END_ADDR = self._compute_end_addr(self.RANGE_BASE_ADDR, self.RANGE_ADDR_WIDTH)
		self.RANGE_LENGTH: int = self.RANGE_END_ADDR - self.RANGE_BASE_ADDR

		# list of busses "FULL_NAMEs" that can reach this range
		self.REACHABLE_FROM: set = set()

	# Used when printing the object 
	def __str__(self):
		return (
			f"{self.RANGE_NAME}: "
			f"0x{self.RANGE_BASE_ADDR:X}-0x{self.RANGE_END_ADDR:X}, "
			f"REACHABLE FROM: {self.REACHABLE_FROM}"
		)

	# Check if this address space contains the address space passed
	def __contains__(self, addr_range: "Addr_Range") -> bool:
		return (self.RANGE_BASE_ADDR <= addr_range.RANGE_BASE_ADDR and
				self.RANGE_END_ADDR >= addr_range.RANGE_END_ADDR)

	# Private function used to compute the range end address based on range base address and address width
	# (the end address is the first address OUTSIDE the range)
	def _compute_end_addr(self, base_addr: int, addr_width: int):
		return base_addr + ~(~ 1 << (addr_width-1)) + 1

	# Splits the range in half, creating a new addr range and returns it
	# this function also set names for the ranges, in order to follow the
	# address ranges naming convention
	# ex. RANGE_NAME = TIM_1, split -> RANGE_NAME = TIM_1_range_0 and RANGE_NAME = TIM_1_range_1
	def split(self, old_range_name: str, new_range_name: str) -> "Addr_Range":
		first_base = self.RANGE_BASE_ADDR
		first_width = self.RANGE_ADDR_WIDTH - 1
		first_end = self._compute_end_addr(first_base, first_width)

		second_base = first_end
		second_width = self.RANGE_ADDR_WIDTH - 1

		# change parameters
		self.RANGE_ADDR_WIDTH = first_width
		self.RANGE_END_ADDR = first_end
		self.RANGE_NAME = old_range_name

		second_range = Addr_Range(new_range_name, second_base, second_width)
		#preserve reachability
		second_range.add_list_to_reachable(list(self.REACHABLE_FROM))
		return second_range
		
	# Add bus "FULL_NAME" to the list of busses that can reach this range
	def add_to_reachable(self, bus_name: str):
		self.REACHABLE_FROM.add(bus_name)
	
	# Add list of busses "FULL_NAMEs" to the list of busses that can reach this range
	def add_list_to_reachable(self, list_of_names: list[str]):
		self.REACHABLE_FROM.update(list_of_names)

	# Get a copy of the list of "FULL_NAMEs" that can reach this addr range
	def get_reachable(self) -> list[str]:
		return list(self.REACHABLE_FROM.copy())

	# Check if this address space is contained in the address space passed
	def is_contained(self, addr_range: "Addr_Range") -> bool:
		return ((addr_range.RANGE_BASE_ADDR <= self.RANGE_BASE_ADDR) and 
		   (self.RANGE_END_ADDR <= addr_range.RANGE_END_ADDR))

	# Check if this address space overlaps with the address space passed
	def overlaps(self, addr_range: "Addr_Range") -> bool:
		return not (self.RANGE_END_ADDR <= addr_range.RANGE_BASE_ADDR or 
					self.RANGE_BASE_ADDR >= addr_range.RANGE_END_ADDR)


class Addr_Ranges():

	# Addr_Ranges Constructor
	def __init__(self, full_name: str, range_base_addr: list[int], range_addr_width: list[int]):
		self.FULL_NAME = full_name
		self.addr_ranges: list[Addr_Range] = []
		self.contiguous: bool = False

		for i in range(len(range_base_addr)):
			range_name = full_name
			range_base = range_base_addr[i]
			range_width = range_addr_width[i]

			# When creating an "Addr_Ranges" object that will contain multiple
			# "Addr_Range", differentiate them using "RANGE_NAME" with a suffix
			# otherwise just copy the FULL_NAME
			if(len(range_base_addr) != 1):
				range_name = self._add_range_suffix(full_name, i)
				
			self.addr_ranges.append(Addr_Range(range_name, range_base, range_width))

		# set the "contiguous" variable checking if the created addresses are contiguous
		self._check_contiguous()
	
	# Used when printing the object 
	def __str__(self):
		lines = "\n".join(str(addr_range) for addr_range in self.addr_ranges)
		return f"{self.FULL_NAME}:\n{lines}"

	# Used to create an iterator over the addr_ranges
	def __iter__(self):
		return iter(self.addr_ranges)

	# Check if the passed "addr_range_chk" object is contained in "self"
	# so that the range "addr_range_chk" is contained in AT LEAST 1 addr range
	# of "self"
	def __contains__(self, addr_range_chk: "Addr_Range") -> bool:
		for addr_range in self.addr_ranges:
			if addr_range_chk in addr_range:
				return True
		return False

	# Internal function used to manipulate "RANGE_NAMES"
	# if the name already contains a range suffix, like "*_range_0"
	# just substitute the number with the number "i" passed, otherwise
	# append the full suffix "_range_str(i)"
	def _add_range_suffix(self, name: str, i: int) -> str:
		# If it already ends with "range_<digits>", replace that part
		if re.search(r"range_\d+$", name):
			return re.sub(r"range_\d+$", f"range_{i}", name)
		# Otherwise append it
		return f"{name}_range_{i}"


	# Internal function used to check if all the address ranges are contiguous
	def _check_contiguous(self):
		# sort the ranges ascending respect to BASE_ADDR in order 
		# to facilitate the check
		self.addr_ranges = sorted(self.addr_ranges, key= lambda x: x.RANGE_BASE_ADDR)
		for i, addr_range in enumerate(self.addr_ranges):
			# skip the first iteration
			if (i == 0):
				continue

			# check if previous range ends where this one starts
			if self.addr_ranges[i-1].RANGE_END_ADDR != addr_range.RANGE_BASE_ADDR:
				self.contiguous = False
				return

		self.contiguous = True

	# Check if the passed "addr_ranges_chk" object overlaps with "self"
	# so that AT LEAST 1 addr range of "addr_ranges_chk" overlaps with AT LEAST 1 addr range of "self"
	def overlaps(self, addr_ranges_chk: "Addr_Ranges") -> bool:
		for addr_range in addr_ranges_chk.addr_ranges:
			if (any(addr_range.overlaps(self_range) for self_range in self.addr_ranges)):
				return True
		return False

	# Split all the address ranges in half and adjust their RANGE_NAMEs
	def split_addr_ranges(self):
		new_ranges = []
		for i, addr_range in enumerate(self.addr_ranges):
			base = addr_range.RANGE_NAME
			old_name = self._add_range_suffix(base, i)
			new_name = self._add_range_suffix(base, i+1)
			new_ranges.append(addr_range.split(old_name, new_name))

		self.addr_ranges.extend(new_ranges)

	# If explicit is set to "True"
	# Returns a key, value dict, each entry represents an addr range with:
	# key = RANGE_NAME
	# value = copy of REACHABLE_FROM
	# if all the ranges have the same "REACHABLE_FROM" and explicit is set to "False"
	# returns a dict with a single entry with:
	# key = FULL_NAME
	# value = copy of REACHABLE_FROM
	def get_reachable_from(self, explicit: bool) -> dict[str, list[str]]:
		ret_dict = {}
		equal = True
		prev_reachables = set()

		for addr_range in self.addr_ranges:
			if(prev_reachables):
				if(prev_reachables != addr_range.REACHABLE_FROM):
					equal = False
					break
			prev_reachables = addr_range.REACHABLE_FROM
		
        # if all ranges share the same REACHABLE_FROM, return just a single entry
		# using "FULL_NAME" as a value (it's used to give a more compact information,
		# if all addr ranges of a Node are addressable from the same Busses, instead
		# of returning information for each addr range, just consider all the addr ranges as a single
		# "FULL_NAME" node)
		# but if only a single range have different REACHABLE_FROM from the other just return
		# informations about every range

		if(equal and not explicit):
			ret_dict = {self.FULL_NAME: list(self.addr_ranges[0].REACHABLE_FROM.copy()) }
		else:
			ret_dict = {addr_range.RANGE_NAME: list(addr_range.REACHABLE_FROM.copy()) for addr_range in self.addr_ranges}

		return ret_dict

	# If explicit is set to "True"
	# Returns a key, value dict, each entry represents an addr range with:
	# key = RANGE_NAME
	# value = (RANGE_BASE, RANGE_END, RANGE_LENGTH)
	# if the ranges are contiguous and explicit is set to "False"
	# returns a dict with a single entry with:
	# key = FULL_NAME
	# value = (RANGE_BASE, RANGE_END, sum of RANGE_LENGTHs)
	def get_range_dimensions(self, explicit: bool) -> dict[str, tuple[int,int,int]]:
		if self.contiguous and not explicit:
			total = sum(addr_range.RANGE_LENGTH for addr_range in self.addr_ranges)
			info = (self.get_base_addr(), self.get_end_addr(), total)
			return {self.FULL_NAME: info}

		return {r.RANGE_NAME: (r.RANGE_BASE_ADDR, r.RANGE_END_ADDR, r.RANGE_LENGTH) for r in self.addr_ranges}

	# Return the base address, that is the smallest base address between all the addr ranges contained
	def get_base_addr(self) -> int:
		return min(addr_range.RANGE_BASE_ADDR for addr_range in self.addr_ranges)

	# Return the end address, that is the biggest end address between all the addr ranges contained
	def get_end_addr(self) -> int:
		return max(addr_range.RANGE_END_ADDR for addr_range in self.addr_ranges)
