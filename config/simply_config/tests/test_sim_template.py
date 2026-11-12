# Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
# Description: tests for the sim templates (run from config/simply_config: python -m pytest tests/)
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from templates.sim_template import Sim_Flist_Template


def test_flist_orders_packages_before_modules(tmp_path):
    # two fake rtl files: a package and a module, written under tmp_path
    rtl = tmp_path / "rtl"; rtl.mkdir()
    (rtl / "b_mod.sv").write_text("module b_mod; endmodule\n")
    (rtl / "a_pkg.sv").write_text("package a_pkg; endpackage\n")
    t = Sim_Flist_Template(incdirs=[str(rtl)], prelude_files=[], rtl_roots=[str(rtl)],
                           exclude_patterns=[], extra_files=[])
    body = t.get_params()["body"]
    assert body.index("a_pkg.sv") < body.index("b_mod.sv")
    assert f"+incdir+{rtl}" in body


def test_flist_tolerates_missing_roots(tmp_path):
    # the generator must not crash on missing/empty rtl_roots
    t = Sim_Flist_Template(incdirs=[], prelude_files=[], rtl_roots=[str(tmp_path / "nope")],
                           exclude_patterns=[], extra_files=[])
    assert t.get_params()["body"] == ""
