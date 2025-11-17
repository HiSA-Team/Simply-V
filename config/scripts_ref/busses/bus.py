from addr_range import Addr_Range
from peripherals.peripheral import Peripheral
from factories.peripherals_factory import Peripherals_Factory
from logger import Logger
from pprint import pprint
from abc import abstractmethod, ABC


class Bus(ABC):
	peripherals_factory = Peripherals_Factory.get_instance()
	logger = Logger.get_instance()

	def __init__(self, data_dict: dict, asgn_addr_range: list[Addr_Range], axi_addr_width: int, axi_data_width: int):
		#remove this
		self.NAME = asgn_addr_range[0].RANGE_NAME

        #General configuration parameters
		self.ID_WIDTH			 : int = data_dict["ID_WIDTH"]
		self.NUM_MI				 : int = data_dict["NUM_MI"]
		self.NUM_SI				 : int = data_dict["NUM_SI"]
		self.MASTER_NAMES        : list[str] = data_dict["MASTER_NAMES"]
		self.PROTOCOL: str = data_dict["PROTOCOL"]
		#Addr ranges assigned to this bus
		self.asgn_addr_range = asgn_addr_range
        #Axi widths
		self.ADDR_WIDTH: int = axi_addr_width
		self.DATA_WIDTH: int = axi_data_width
        #Children Parameters
		self.ADDR_RANGES: int = data_dict["ADDR_RANGES"]
		self.RANGE_NAMES: list[str] = data_dict["RANGE_NAMES"]
		self.RANGE_BASE_ADDR: list[int] = data_dict["RANGE_BASE_ADDR"]
		self.RANGE_ADDR_WIDTH: list[int] = data_dict["RANGE_ADDR_WIDTH"]
		self.children_peripherals : list[Peripheral] = []

				

	def check_peripherals(self, legal_peripherals):
		simply_v_crash = self.logger.simply_v_crash

		for p in self.children_peripherals:
			if p.BASE_NAME not in legal_peripherals:
				simply_v_crash(f"Unsupported peripheral {p.NAME} for this bus")

	
	#Set all the peripherals as reachable from this bus
	def add_reachability(self):
		for peripheral in self.children_peripherals:
			peripheral.add_to_reachable(self.NAME)
			peripheral.add_list_to_reachable(self.REACHABLE_FROM)


	def check_intra(self):
		simply_v_crash = self.logger.simply_v_crash
		for addr_width in self.RANGE_ADDR_WIDTH:
			if addr_width > self.ADDR_WIDTH:
				simply_v_crash(f"RANGE_ADDR_WIDTH is greater than {self.ADDR_WIDTH}")
			
		# compute end addresses after all the checks
		self.RANGE_END_ADDR = self.compute_range_end_addresses(self.RANGE_BASE_ADDR, self.RANGE_ADDR_WIDTH)

		for i in range(len(self.RANGE_BASE_ADDR)):
			base_address = self.RANGE_BASE_ADDR[i]
			end_address = self.RANGE_END_ADDR[i]

			# Check if the base addr does not fall into the addr range (e.g. base_addr: 0x100 is not allowed with range_width=12)
			if (base_address & ~(~1 << (self.RANGE_ADDR_WIDTH[i]-1)) ) != 0:
				simply_v_crash(f"BASE_ADDR [{i}] does not match RANGE_ADDR_WIDTH [{i}]")

				# Check if the current address does not fall into the addr range one of the previous slaves
			for j in range(len(self.RANGE_BASE_ADDR)):
				# Skip yourself from the check
				if (i == j):
					continue
					
				if  ((base_address < self.RANGE_END_ADDR[j])   and (base_address >= self.RANGE_BASE_ADDR[j])) or \
					((end_address > self.RANGE_BASE_ADDR[j])   and (base_address <= self.RANGE_BASE_ADDR[j])) or \
					((base_address <= self.RANGE_BASE_ADDR[j])  and (end_address >= self.RANGE_END_ADDR[j])  ) or \
					((base_address >= self.RANGE_BASE_ADDR[j])  and (end_address <= self.RANGE_END_ADDR[j])  ):

					simply_v_crash(f"Address of {self.RANGE_NAMES[i]} overlaps with {self.RANGE_NAMES[j]}")
		

	def check_inter(self):
		#for each node connected to the bus check if it's included in at least
		#one bus address range
		for base, end in zip(self.RANGE_BASE_ADDR, self.RANGE_END_ADDR):
			if (not self.contains(base, end)):
				self.logger.simply_v_crash(f"The addresses assigned to some Node (Peripheral or Bus) in this bus "
						"don't fit in the address ranges assigned to this bus from his parent bus.")

	
	def get_peripherals(self) -> list[Peripheral]:
		return self.children_peripherals


	def print_vars(self):
		for peripheral in self.children_peripherals:
			print(f"Printing {peripheral.NAME}\n")
			pprint(vars(peripheral))
			print("\n")

	
	#COMPOSITE INTERFACE
	@abstractmethod
	def check_clock_domains(self):
		pass


	@abstractmethod
	def init_clock_domains(self):
		pass


	@abstractmethod
	def generate_children(self):
		pass


	@abstractmethod
	def get_busses(self) -> list["Bus"]:
		pass
