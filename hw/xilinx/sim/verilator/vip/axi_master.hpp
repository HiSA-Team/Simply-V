// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: AXI4 master VIP on the jtag_axi_* port of the simulation wrapper (the
//              JTAG2AXI master on the FPGA): 32-bit single-beat INCR writes,
//              one outstanding, ID 0. Calls are blocking and advance time only
//              through the testbench tick(); handshakes are sampled before the edge.

#ifndef SIMPLYV_AXI_MASTER_HPP
#define SIMPLYV_AXI_MASTER_HPP

#include <cstdint>
#include <functional>
#include <vector>

template <class Top>
class AxiMaster {
public:
    AxiMaster(Top& t, std::function<void()> tick) : t_(t), tick_(tick) {
        t_.jtag_axi_awvalid = t_.jtag_axi_wvalid = t_.jtag_axi_bready = 0;
        t_.jtag_axi_arvalid = t_.jtag_axi_rready = 0;
        t_.jtag_axi_awid = t_.jtag_axi_arid = 0;
        t_.jtag_axi_awlen = t_.jtag_axi_arlen = 0;
        t_.jtag_axi_awsize = t_.jtag_axi_arsize = 2;
        t_.jtag_axi_awburst = t_.jtag_axi_arburst = 1;
        t_.jtag_axi_awlock = t_.jtag_axi_awcache = t_.jtag_axi_awprot = 0;
        t_.jtag_axi_awqos = t_.jtag_axi_awregion = 0;
        t_.jtag_axi_arlock = t_.jtag_axi_arcache = t_.jtag_axi_arprot = 0;
        t_.jtag_axi_arqos = t_.jtag_axi_arregion = 0;
        t_.jtag_axi_wstrb = 0xf;
        t_.jtag_axi_wlast = 1;
    }

    // AW and W are raised together: a slave may wait for both valids
    void write(uint64_t addr, uint32_t data) {
        t_.jtag_axi_awaddr = addr;
        t_.jtag_axi_wdata  = data;
        t_.jtag_axi_awvalid = t_.jtag_axi_wvalid = 1;
        while (t_.jtag_axi_awvalid || t_.jtag_axi_wvalid) {
            t_.eval();
            const bool aw = t_.jtag_axi_awready, w = t_.jtag_axi_wready;
            tick_();
            if (aw) t_.jtag_axi_awvalid = 0;
            if (w)  t_.jtag_axi_wvalid  = 0;
        }
        t_.jtag_axi_bready = 1;
        for (bool b = false; !b; ) { t_.eval(); b = t_.jtag_axi_bvalid; err_ |= b && (t_.jtag_axi_bresp & 2); tick_(); }
        t_.jtag_axi_bready = 0;
    }

    // Same transactions as jtag2axi_load_binary.tcl: one little-endian word per write,
    // ascending addresses, the tail zero-padded to a word
    void load(uint64_t base, const std::vector<uint8_t>& image) {
        for (size_t i = 0; i < image.size(); i += 4) {
            uint32_t w = 0;
            for (size_t b = 0; b < 4 && i + b < image.size(); ++b) w |= uint32_t(image[i + b]) << (8 * b);
            write(base + i, w);
        }
    }

    bool error() const { return err_; }

private:
    Top& t_;
    std::function<void()> tick_;
    bool err_ = false;
};

#endif // SIMPLYV_AXI_MASTER_HPP
