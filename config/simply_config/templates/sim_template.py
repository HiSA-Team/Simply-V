# Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
# Description:
#   Filelist of the simulation flow, shared by the Verilator and xsim backends.

import os
import re
import textwrap
from .template import Template


class Sim_Flist_Template(Template):
	# Simulation filelist (.f): include dirs, then sources with all
	# SV packages listed before the modules that import them.

	_str_template: str = textwrap.dedent("""\
	# This file is auto-generated with {this_file}
	{body}
	""")

	def __init__(self, incdirs, prelude_files, rtl_roots,
				 exclude_patterns, extra_files):
		self.incdirs = incdirs
		self.prelude_files = prelude_files
		self.rtl_roots = rtl_roots
		self.exclude_patterns = exclude_patterns
		self.extra_files = extra_files

	# Walk the rtl roots collecting .sv files, split into packages vs modules
	# (packages must be compiled first). Missing/empty roots are tolerated:
	# os.walk on a non-existent dir simply yields nothing.
	# Units vendor their own copy of shared cells: the first root wins, on every simulator
	def _collect(self):
		pkg_re = re.compile(r"^\s*package\s+\w", re.M)
		excl_re = re.compile("|".join(self.exclude_patterns)) if self.exclude_patterns else None
		pkgs, mods, seen = [], [], set()
		for root in self.rtl_roots:
			for dirpath, _, files in sorted(os.walk(root)):
				for f in sorted(files):
					if not f.endswith(".sv") or f in seen:
						continue
					path = os.path.join(dirpath, f)
					if excl_re and excl_re.search(path):
						continue
					seen.add(f)
					with open(path, encoding="utf-8", errors="ignore") as fh:
						(pkgs if pkg_re.search(fh.read()) else mods).append(path)
		return pkgs, mods

	# Used by template.py in the write_to_file implementation
	def get_params(self) -> dict[str, str]:
		pkgs, mods = self._collect()
		lines  = [f"+incdir+{i}" for i in self.incdirs]
		lines += self.prelude_files + pkgs + mods + self.extra_files
		return {"this_file": os.path.basename(__file__), "body": "\n".join(lines)}
