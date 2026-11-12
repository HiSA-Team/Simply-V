# Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
# Description: tests for the crossbar svinc generator (run from config/simply_config: python -m pytest tests/)
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pytest

from templates.bus_crossbar_template import Bus_Crossbar_Template
from general.addr_range import Addr_Ranges


class FakeMbus:
    FULL_NAME = "MBUS"; PROTOCOL = "AXI4"
    def get_ordered_children_ranges(self):
        return [Addr_Ranges("BRAM_0", [0x0], [16]), Addr_Ranges("PBUS", [0x20000], [16]),
                Addr_Ranges("PLIC", [0x4000000], [26])]


class FakePbus:
    FULL_NAME = "PBUS"; PROTOCOL = "AXI4LITE"
    def get_ordered_children_ranges(self):
        return [Addr_Ranges("UART", [0x20000], [4]), Addr_Ranges("GPIOOUT", [0x20200], [9])]


class FakeMultiRange(FakeMbus):
    def get_ordered_children_ranges(self):
        return [Addr_Ranges("BRAM_0", [0x0, 0x100], [4, 4]), Addr_Ranges("PLIC", [0x4000000], [26])]


def render(bus, xbar_impl="XILINX"):
    t = Bus_Crossbar_Template(bus, xbar_impl)
    # Whitespace-insensitive: column alignment is cosmetic
    return " ".join(t._str_template.format(**t.get_params()).split())


def test_mbus_map_and_instances():
    out = render(FakeMbus())
    # Master port 0 is the least significant element
    assert "MBUS_XBAR_BASE = {MBUS_ADDR_WIDTH'('h4000000), MBUS_ADDR_WIDTH'('h20000), MBUS_ADDR_WIDTH'('h0)};" in out
    assert "MBUS_XBAR_BITS = {8'd26, 8'd16, 8'd16};" in out
    assert "simplyv_axi_xbar #(" in out and "xlnx_mbus_crossbar mbus_xbar_u (" in out
    assert ".s_axi_awregion ( MBUS_masters_axi_awregion )" in out
    # The Xilinx IP has region signals on the master side only
    assert out.count("MBUS_masters_axi_awregion") == 1 and out.count("MBUS_slaves_axi_awregion") == 2
    assert "( MBUS_clk )" in out


def test_pbus_is_axilite():
    out = render(FakePbus())
    assert "simplyv_axilite_xbar #(" in out and "xlnx_pbus_crossbar pbus_xbar_u (" in out
    assert ".s_axilite_awaddr ( PBUS_masters_axilite_awaddr )" in out
    assert ".s_axi_awaddr ( PBUS_masters_axilite_awaddr )" in out
    assert "ID_WIDTH" not in out and "( PBUS_clock_i )" in out


def test_multi_range_child():
    render(FakeMultiRange(), "XILINX")
    with pytest.raises(ValueError, match="one address range"):
        render(FakeMultiRange(), "CUSTOM")
