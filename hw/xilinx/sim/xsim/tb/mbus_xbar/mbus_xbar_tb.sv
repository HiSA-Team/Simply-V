// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: MBUS crossbar bench (xsim, Xilinx AXI VIP). The DUT is the crossbar of
//              the generated mbus_crossbar.svinc, i.e. the CSV address map and XBAR_IMPL.
//              One master VIP per slave port, one slave memory VIP per master port.
//              Every master writes random bursts to random slaves and reads them back;
//              routing is checked by a backdoor read of the target memory. An unmapped
//              address must get DECERR (and 'h5BADBEEF read data with XBAR_CUSTOM).

`timescale 1ns / 1ps

`include "simplyv_axi.svh"

import axi_vip_pkg::*;
import simplyv_pkg::*;

// VIP port <-> element i of a bus array
`define VIP_AXI_PORTS(vip_side, array_name, i)                                                    \
    .``vip_side``_axi_awid    ( ``array_name``_axi_awid[i]     ), .``vip_side``_axi_awaddr  ( ``array_name``_axi_awaddr[i]   ), \
    .``vip_side``_axi_awlen   ( ``array_name``_axi_awlen[i]    ), .``vip_side``_axi_awsize  ( ``array_name``_axi_awsize[i]   ), \
    .``vip_side``_axi_awburst ( ``array_name``_axi_awburst[i]  ), .``vip_side``_axi_awlock  ( ``array_name``_axi_awlock[i]   ), \
    .``vip_side``_axi_awcache ( ``array_name``_axi_awcache[i]  ), .``vip_side``_axi_awprot  ( ``array_name``_axi_awprot[i]   ), \
    .``vip_side``_axi_awregion( ``array_name``_axi_awregion[i] ), .``vip_side``_axi_awqos   ( ``array_name``_axi_awqos[i]    ), \
    .``vip_side``_axi_awvalid ( ``array_name``_axi_awvalid[i]  ), .``vip_side``_axi_awready ( ``array_name``_axi_awready[i]  ), \
    .``vip_side``_axi_wdata   ( ``array_name``_axi_wdata[i]    ), .``vip_side``_axi_wstrb   ( ``array_name``_axi_wstrb[i]    ), \
    .``vip_side``_axi_wlast   ( ``array_name``_axi_wlast[i]    ), .``vip_side``_axi_wvalid  ( ``array_name``_axi_wvalid[i]   ), \
    .``vip_side``_axi_wready  ( ``array_name``_axi_wready[i]   ), .``vip_side``_axi_bid     ( ``array_name``_axi_bid[i]      ), \
    .``vip_side``_axi_bresp   ( ``array_name``_axi_bresp[i]    ), .``vip_side``_axi_bvalid  ( ``array_name``_axi_bvalid[i]   ), \
    .``vip_side``_axi_bready  ( ``array_name``_axi_bready[i]   ), .``vip_side``_axi_arid    ( ``array_name``_axi_arid[i]     ), \
    .``vip_side``_axi_araddr  ( ``array_name``_axi_araddr[i]   ), .``vip_side``_axi_arlen   ( ``array_name``_axi_arlen[i]    ), \
    .``vip_side``_axi_arsize  ( ``array_name``_axi_arsize[i]   ), .``vip_side``_axi_arburst ( ``array_name``_axi_arburst[i]  ), \
    .``vip_side``_axi_arlock  ( ``array_name``_axi_arlock[i]   ), .``vip_side``_axi_arcache ( ``array_name``_axi_arcache[i]  ), \
    .``vip_side``_axi_arprot  ( ``array_name``_axi_arprot[i]   ), .``vip_side``_axi_arregion( ``array_name``_axi_arregion[i] ), \
    .``vip_side``_axi_arqos   ( ``array_name``_axi_arqos[i]    ), .``vip_side``_axi_arvalid ( ``array_name``_axi_arvalid[i]  ), \
    .``vip_side``_axi_arready ( ``array_name``_axi_arready[i]  ), .``vip_side``_axi_rid     ( ``array_name``_axi_rid[i]      ), \
    .``vip_side``_axi_rdata   ( ``array_name``_axi_rdata[i]    ), .``vip_side``_axi_rresp   ( ``array_name``_axi_rresp[i]    ), \
    .``vip_side``_axi_rlast   ( ``array_name``_axi_rlast[i]    ), .``vip_side``_axi_rvalid  ( ``array_name``_axi_rvalid[i]   ), \
    .``vip_side``_axi_rready  ( ``array_name``_axi_rready[i]   )

module mbus_xbar_tb;

    localparam int unsigned AW = MBUS_ADDR_WIDTH;
    localparam int unsigned DW = MBUS_DATA_WIDTH;
    localparam int unsigned IW = MBUS_ID_WIDTH;
    // ID bits returned to a master by the Xilinx IP, the slave-port index is above them
    localparam int unsigned THREAD_ID_WIDTH = IW - $clog2(MBUS_NUM_SI);
    localparam logic [DW-1:0] ERR_RDATA = {(DW/32){32'h5BADBEEF}};
    localparam xil_axi_size_t BEAT_SIZE = xil_axi_size_t'($clog2(DW / 8));

    logic MBUS_clk  = 1'b0;
    logic MBUS_rstn = 1'b0;
    always #5 MBUS_clk = ~MBUS_clk;

    /////////
    // DUT //
    /////////
    `DECLARE_AXI_BUS_ARRAY(MBUS_masters, MBUS_NUM_SI, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH)
    `DECLARE_AXI_BUS_ARRAY(MBUS_slaves, MBUS_NUM_MI, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH)
    `include "generated/interconnects/mbus_crossbar.svinc"

    //////////
    // VIPs //
    //////////
    typedef axi_mst_agent     #(0, AW, DW, DW, IW, IW, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1) mst_t;
    typedef axi_slv_mem_agent #(0, AW, DW, DW, IW, IW, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1) slv_t;
    mst_t mst [MBUS_NUM_SI];
    slv_t slv [MBUS_NUM_MI];

    for (genvar i = 0; i < MBUS_NUM_SI; i++) begin : g_mst
        axi_vip_v1_1_19_top #(
            .C_AXI_PROTOCOL(0), .C_AXI_INTERFACE_MODE(0), .C_AXI_ADDR_WIDTH(AW), .C_AXI_WDATA_WIDTH(DW),
            .C_AXI_RDATA_WIDTH(DW), .C_AXI_WID_WIDTH(IW), .C_AXI_RID_WIDTH(IW)
        ) vip (
            .aclk(MBUS_clk), .aclken(1'b1), .aresetn(MBUS_rstn),
            `VIP_AXI_PORTS(m, MBUS_masters, i)
        );
        initial mst[i] = new($sformatf("m%0d", i), vip.IF);
    end

    for (genvar j = 0; j < MBUS_NUM_MI; j++) begin : g_slv
        axi_vip_v1_1_19_top #(
            .C_AXI_PROTOCOL(0), .C_AXI_INTERFACE_MODE(2), .C_AXI_ADDR_WIDTH(AW), .C_AXI_WDATA_WIDTH(DW),
            .C_AXI_RDATA_WIDTH(DW), .C_AXI_WID_WIDTH(IW), .C_AXI_RID_WIDTH(IW)
        ) vip (
            .aclk(MBUS_clk), .aclken(1'b1), .aresetn(MBUS_rstn),
            `VIP_AXI_PORTS(s, MBUS_slaves, j)
        );
        initial slv[j] = new($sformatf("s%0d", j), vip.IF);
    end

    ///////////
    // Tests //
    ///////////
    int errors = 0;

    function automatic bit is_mapped(logic [AW-1:0] addr);
        is_mapped = 1'b0;
        for (int j = 0; j < MBUS_NUM_MI; j++)
            is_mapped |= (addr >> MBUS_XBAR_BITS[j]) == (MBUS_XBAR_BASE[j] >> MBUS_XBAR_BITS[j]);
    endfunction

    // First address past the end of a slave that no slave decodes
    function automatic logic [AW-1:0] unmapped_addr();
        logic [AW-1:0] addr;
        unmapped_addr = '0;
        for (int j = MBUS_NUM_MI - 1; j >= 0; j--) begin
            addr = MBUS_XBAR_BASE[j] + (AW'(1) << MBUS_XBAR_BITS[j]);
            if (!is_mapped(addr)) unmapped_addr = addr;
        end
    endfunction

    // n write/read-back bursts from master i; each master owns a slice of every slave
    task automatic traffic(int i, int n);
        axi_transaction wr, rd;
        bit [8*4096-1:0] wdata, rdata;
        xil_axi_ulong lo, hi, slice;
        xil_axi_uint  tid_max = (1 << THREAD_ID_WIDTH) - 1;
        int j;
        repeat (n) begin
            j     = $urandom_range(MBUS_NUM_MI - 1);
            slice = (64'(1) << MBUS_XBAR_BITS[j]) >> $clog2(MBUS_NUM_SI);
            lo    = MBUS_XBAR_BASE[j] + i * slice;
            hi    = lo + slice - 8 * DW / 8;
            wr = mst[i].wr_driver.create_transaction($sformatf("m%0d_wr", i));
            if (!wr.randomize() with { addr inside {[lo:hi]}; addr % (DW / 8) == 0; len < 8;
                                       burst == XIL_AXI_BURST_TYPE_INCR; size == BEAT_SIZE;
                                       id <= tid_max; })
                $fatal(1, "randomize");
            wr.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
            mst[i].wr_driver.send(wr);
            mst[i].wr_driver.wait_rsp(wr);
            rd = mst[i].rd_driver.create_transaction($sformatf("m%0d_rd", i));
            rd.set_read_cmd(wr.get_addr(), wr.get_burst(), wr.get_id(), wr.get_len(), wr.get_size());
            rd.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
            mst[i].rd_driver.send(rd);
            mst[i].rd_driver.wait_rsp(rd);
            wdata = wr.get_data_block();
            rdata = rd.get_data_block();
            if (wr.get_bresp() != XIL_AXI_RESP_OKAY || rdata !== wdata) begin
                errors++;
                $display("ERROR m%0d -> s%0d @%h: bresp %0d, read back %s", i, j, wr.get_addr(), wr.get_bresp(),
                         rdata === wdata ? "ok" : "differs");
            end
            for (int k = 0; k <= wr.get_len(); k++)
                if (slv[j].mem_model.backdoor_memory_read(wr.get_addr() + k * DW / 8) !== wdata[DW*k +: DW]) begin
                    errors++;
                    $display("ERROR routing m%0d -> s%0d beat %0d", i, j, k);
                end
        end
    endtask

    // Unmapped write and read from master 0, with the VIP response checks off
    task automatic decerr();
        axi_transaction wr, rd;
        bit [8*4096-1:0] rdata;
        logic [AW-1:0] addr = unmapped_addr();
        g_mst[0].vip.IF.clr_write_response_error_check();
        g_mst[0].vip.IF.clr_read_response_error_check();
        wr = mst[0].wr_driver.create_transaction("decerr_wr");
        wr.set_write_cmd(addr, XIL_AXI_BURST_TYPE_INCR, 0, 1, BEAT_SIZE);
        wr.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
        mst[0].wr_driver.send(wr);
        mst[0].wr_driver.wait_rsp(wr);
        rd = mst[0].rd_driver.create_transaction("decerr_rd");
        rd.set_read_cmd(addr, XIL_AXI_BURST_TYPE_INCR, 0, 1, BEAT_SIZE);
        rd.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
        mst[0].rd_driver.send(rd);
        mst[0].rd_driver.wait_rsp(rd);
        g_mst[0].vip.IF.set_write_response_error_check();
        g_mst[0].vip.IF.set_read_response_error_check();
        if (wr.get_bresp() != XIL_AXI_RESP_DECERR || rd.get_rresp(0) != XIL_AXI_RESP_DECERR || rd.get_rresp(1) != XIL_AXI_RESP_DECERR) begin
            errors++;
            $display("ERROR @%h: no DECERR", addr);
        end
        rdata = rd.get_data_block();
        if (XBAR_IMPL == XBAR_CUSTOM && rdata[2*DW-1:0] !== {ERR_RDATA, ERR_RDATA}) begin
            errors++;
            $display("ERROR @%h: read data %h", addr, rdata[2*DW-1:0]);
        end
    endtask

    initial begin
        repeat (20) @(posedge MBUS_clk);
        MBUS_rstn <= 1'b1;
        repeat (10) @(posedge MBUS_clk);
        foreach (slv[j]) slv[j].start_slave();
        foreach (mst[i]) mst[i].start_master();
        for (int i = 0; i < MBUS_NUM_SI; i++)
            fork
                automatic int fi = i;
                traffic(fi, 100);
            join_none
        wait fork;
        decerr();
        foreach (mst[i]) mst[i].wait_drivers_idle();
        $display("[MBUS-XBAR] %s %s errors=%0d", XBAR_IMPL.name(), errors ? "FAIL" : "PASS", errors);
        $finish;
    end

endmodule
