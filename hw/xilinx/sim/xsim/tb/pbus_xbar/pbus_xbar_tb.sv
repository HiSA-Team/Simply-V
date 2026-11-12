// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: PBUS crossbar bench (xsim, Xilinx AXI VIP). The DUT is the crossbar of
//              the generated pbus_crossbar.svinc, i.e. the CSV address map and XBAR_IMPL.
//              One AXI-Lite master VIP per slave port, one AXI-Lite slave memory VIP per
//              master port. Random writes to every slave are read back and checked by a
//              backdoor read of the target memory. An unmapped address must get DECERR
//              (and 'h5BADBEEF read data with XBAR_CUSTOM).

`timescale 1ns / 1ps

`include "simplyv_axi.svh"

import axi_vip_pkg::*;
import simplyv_pkg::*;

// VIP port <-> element i of a bus array
`define VIP_AXILITE_PORTS(vip_side, array_name, i)                                                         \
    .``vip_side``_axi_awaddr  ( ``array_name``_axilite_awaddr[i]  ), .``vip_side``_axi_awprot  ( ``array_name``_axilite_awprot[i]  ), \
    .``vip_side``_axi_awvalid ( ``array_name``_axilite_awvalid[i] ), .``vip_side``_axi_awready ( ``array_name``_axilite_awready[i] ), \
    .``vip_side``_axi_wdata   ( ``array_name``_axilite_wdata[i]   ), .``vip_side``_axi_wstrb   ( ``array_name``_axilite_wstrb[i]   ), \
    .``vip_side``_axi_wvalid  ( ``array_name``_axilite_wvalid[i]  ), .``vip_side``_axi_wready  ( ``array_name``_axilite_wready[i]  ), \
    .``vip_side``_axi_bresp   ( ``array_name``_axilite_bresp[i]   ), .``vip_side``_axi_bvalid  ( ``array_name``_axilite_bvalid[i]  ), \
    .``vip_side``_axi_bready  ( ``array_name``_axilite_bready[i]  ), .``vip_side``_axi_araddr  ( ``array_name``_axilite_araddr[i]  ), \
    .``vip_side``_axi_arprot  ( ``array_name``_axilite_arprot[i]  ), .``vip_side``_axi_arvalid ( ``array_name``_axilite_arvalid[i] ), \
    .``vip_side``_axi_arready ( ``array_name``_axilite_arready[i] ), .``vip_side``_axi_rdata   ( ``array_name``_axilite_rdata[i]   ), \
    .``vip_side``_axi_rresp   ( ``array_name``_axilite_rresp[i]   ), .``vip_side``_axi_rvalid  ( ``array_name``_axilite_rvalid[i]  ), \
    .``vip_side``_axi_rready  ( ``array_name``_axilite_rready[i]  )

module pbus_xbar_tb;

    localparam int unsigned AW = PBUS_ADDR_WIDTH;
    localparam int unsigned DW = PBUS_DATA_WIDTH;
    localparam logic [DW-1:0] ERR_RDATA = {(DW/32){32'h5BADBEEF}};

    logic PBUS_clock_i  = 1'b0;
    logic PBUS_reset_ni = 1'b0;
    always #5 PBUS_clock_i = ~PBUS_clock_i;

    /////////
    // DUT //
    /////////
    `DECLARE_AXILITE_BUS_ARRAY(PBUS_masters, PBUS_NUM_SI, PBUS_DATA_WIDTH, PBUS_ADDR_WIDTH)
    `DECLARE_AXILITE_BUS_ARRAY(PBUS_slaves, PBUS_NUM_MI, PBUS_DATA_WIDTH, PBUS_ADDR_WIDTH)
    `include "generated/interconnects/pbus_crossbar.svinc"

    //////////
    // VIPs //
    //////////
    typedef axi_mst_agent     #(2, AW, DW, DW, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1) mst_t;
    typedef axi_slv_mem_agent #(2, AW, DW, DW, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1) slv_t;
    mst_t mst [PBUS_NUM_SI];
    slv_t slv [PBUS_NUM_MI];

    for (genvar i = 0; i < PBUS_NUM_SI; i++) begin : g_mst
        axi_vip_v1_1_19_top #(
            .C_AXI_PROTOCOL(2), .C_AXI_INTERFACE_MODE(0), .C_AXI_ADDR_WIDTH(AW), .C_AXI_WDATA_WIDTH(DW),
            .C_AXI_RDATA_WIDTH(DW), .C_AXI_SUPPORTS_NARROW(0), .C_AXI_HAS_BURST(0), .C_AXI_HAS_LOCK(0),
            .C_AXI_HAS_CACHE(0), .C_AXI_HAS_REGION(0), .C_AXI_HAS_QOS(0)
        ) vip (
            .aclk(PBUS_clock_i), .aclken(1'b1), .aresetn(PBUS_reset_ni),
            `VIP_AXILITE_PORTS(m, PBUS_masters, i)
        );
        initial mst[i] = new($sformatf("m%0d", i), vip.IF);
    end

    for (genvar j = 0; j < PBUS_NUM_MI; j++) begin : g_slv
        axi_vip_v1_1_19_top #(
            .C_AXI_PROTOCOL(2), .C_AXI_INTERFACE_MODE(2), .C_AXI_ADDR_WIDTH(AW), .C_AXI_WDATA_WIDTH(DW),
            .C_AXI_RDATA_WIDTH(DW), .C_AXI_SUPPORTS_NARROW(0), .C_AXI_HAS_BURST(0), .C_AXI_HAS_LOCK(0),
            .C_AXI_HAS_CACHE(0), .C_AXI_HAS_REGION(0), .C_AXI_HAS_QOS(0)
        ) vip (
            .aclk(PBUS_clock_i), .aclken(1'b1), .aresetn(PBUS_reset_ni),
            `VIP_AXILITE_PORTS(s, PBUS_slaves, j)
        );
        initial slv[j] = new($sformatf("s%0d", j), vip.IF);
    end

    ///////////
    // Tests //
    ///////////
    int errors = 0;

    function automatic bit is_mapped(logic [AW-1:0] addr);
        is_mapped = 1'b0;
        for (int j = 0; j < PBUS_NUM_MI; j++)
            is_mapped |= (addr >> PBUS_XBAR_BITS[j]) == (PBUS_XBAR_BASE[j] >> PBUS_XBAR_BITS[j]);
    endfunction

    // First address past the end of a slave that no slave decodes
    function automatic logic [AW-1:0] unmapped_addr();
        logic [AW-1:0] addr;
        unmapped_addr = '0;
        for (int j = PBUS_NUM_MI - 1; j >= 0; j--) begin
            addr = PBUS_XBAR_BASE[j] + (AW'(1) << PBUS_XBAR_BITS[j]);
            if (!is_mapped(addr)) unmapped_addr = addr;
        end
    endfunction

    // n write/read-back pairs from master i; each master owns a slice of every slave
    task automatic traffic(int i, int n);
        xil_axi_resp_t   resp;
        bit [8*8-1:0]    rdata;
        logic [DW-1:0]   wdata;
        logic [AW-1:0]   addr, slice;
        int j;
        repeat (n) begin
            j     = $urandom_range(PBUS_NUM_MI - 1);
            slice = (AW'(1) << PBUS_XBAR_BITS[j]) >> $clog2(PBUS_NUM_SI);
            addr  = PBUS_XBAR_BASE[j] + i * slice + ($urandom_range(slice - 1) & ~AW'(DW / 8 - 1));
            wdata = {(DW/32){$urandom()}};
            mst[i].AXI4LITE_WRITE_BURST(addr, 0, wdata, resp);
            if (resp != XIL_AXI_RESP_OKAY) begin errors++; $display("ERROR m%0d -> s%0d @%h: bresp %0d", i, j, addr, resp); end
            mst[i].AXI4LITE_READ_BURST(addr, 0, rdata, resp);
            if (resp != XIL_AXI_RESP_OKAY || rdata[DW-1:0] !== wdata) begin
                errors++;
                $display("ERROR m%0d -> s%0d @%h: rresp %0d, read %h, expected %h", i, j, addr, resp, rdata[DW-1:0], wdata);
            end
            if (slv[j].mem_model.backdoor_memory_read(addr) !== wdata) begin
                errors++;
                $display("ERROR routing m%0d -> s%0d @%h", i, j, addr);
            end
        end
    endtask

    // Unmapped write and read from master 0, with the VIP response checks off
    task automatic decerr();
        xil_axi_resp_t bresp, rresp;
        bit [8*8-1:0]  rdata;
        logic [AW-1:0] addr = unmapped_addr();
        g_mst[0].vip.IF.clr_write_response_error_check();
        g_mst[0].vip.IF.clr_read_response_error_check();
        mst[0].AXI4LITE_WRITE_BURST(addr, 0, '0, bresp);
        mst[0].AXI4LITE_READ_BURST(addr, 0, rdata, rresp);
        g_mst[0].vip.IF.set_write_response_error_check();
        g_mst[0].vip.IF.set_read_response_error_check();
        if (bresp != XIL_AXI_RESP_DECERR || rresp != XIL_AXI_RESP_DECERR) begin
            errors++;
            $display("ERROR @%h: no DECERR", addr);
        end
        if (XBAR_IMPL == XBAR_CUSTOM && rdata[DW-1:0] !== ERR_RDATA) begin
            errors++;
            $display("ERROR @%h: read data %h", addr, rdata[DW-1:0]);
        end
    endtask

    initial begin
        repeat (20) @(posedge PBUS_clock_i);
        PBUS_reset_ni <= 1'b1;
        repeat (10) @(posedge PBUS_clock_i);
        foreach (slv[j]) slv[j].start_slave();
        foreach (mst[i]) mst[i].start_master();
        for (int i = 0; i < PBUS_NUM_SI; i++)
            fork
                automatic int fi = i;
                traffic(fi, 200);
            join_none
        wait fork;
        decerr();
        foreach (mst[i]) mst[i].wait_drivers_idle();
        $display("[PBUS-XBAR] %s %s errors=%0d", XBAR_IMPL.name(), errors ? "FAIL" : "PASS", errors);
        $finish;
    end

endmodule
