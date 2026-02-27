# Author: Salvatore Santoro				<sal.santoro@studenti.unina.it>
# Description:
#   Abstract template class that implement the actual writing to file and template formatting
#	each concrete template must implement the "_get_params" method that need to retrieve a key, value mapping
#   of all the symbols and their effective values needed for the template generation


from abc import ABC, abstractmethod

class Template(ABC):
	_str_template: str = ""

	@abstractmethod
	def get_params(self) -> dict[str, str]:
		pass

	def write_to_file(self, file_name: str) -> None:
		formatted = self._str_template.format(**self.get_params())
		with open(file_name, "w", encoding="utf-8") as f:
			f.write(formatted)

