// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: xsim testbench of the embedded SoC (simplyv_sim_wrapper), the SV twin of the
//              Verilator one. Holds the core in reset, loads the program into BRAM_0
//              through a Xilinx AXI VIP master (as load_binary does on the FPGA),
//              releases the core reset and compares the UART output with the golden
//              file: "[EMB] PASS" or "[EMB] FAIL".
//              Plusargs: +BIN=<program.bin> +GOLDEN=<file> [+STIMULUS=<file>], the
//              stimulus is sent on uart_rx_i once the firmware prints its prompt.

`timescale 1ns / 1ps

`include "simplyv_axi.svh"

import axi_vip_pkg::*;
import simplyv_pkg::*;

module simplyv_tb;

    localparam int unsigned AW = MBUS_ADDR_WIDTH;
    localparam int unsigned IW = MBUS_ID_WIDTH;
    localparam int unsigned CPB = `SIM_UART_CYCLES_PER_BIT;
    // gpio_in toggle period: each toggle raises a GPIO_IN interrupt (interrupts test).
    // 4000 UART bits, longer than the handlers' printf, so the interrupts do not pile up
    localparam int unsigned GPIO_TOGGLE_PERIOD = 4000 * CPB;
    localparam string PROMPT = "Please enter a string";

    // One clock in simulation: every clock pin is driven by clk
    logic clk = 1'b0, locked = 1'b0, vio_resetn = 1'b0;
    logic uart_tx, uart_rx = 1'b1;
    logic [GPIO_IN_WIDTH-1:0]  gpio_in = '0;
    logic [GPIO_OUT_WIDTH-1:0] gpio_out;
    always #25 clk = ~clk;

    /////////
    // DUT //
    /////////
    `DECLARE_AXI_BUS(jtag, 32, AW, IW)

    simplyv_sim_wrapper dut (
        .sys_clock_i  ( clk        ),
        .sys_reset_i  ( ~locked    ),
        .uart_rx_i    ( uart_rx    ),
        .uart_tx_o    ( uart_tx    ),
        .gpio_in_i    ( gpio_in    ),
        .gpio_out_o   ( gpio_out   ),
        .clk_10MHz_i  ( clk        ),
        .clk_20MHz_i  ( clk        ),
        .clk_50MHz_i  ( clk        ),
        .clk_100MHz_i ( clk        ),
        .locked_i     ( locked     ),
        .vio_resetn_i ( vio_resetn ),
        .jtag_axi_awid     ( jtag_axi_awid     ),
        .jtag_axi_awaddr   ( jtag_axi_awaddr   ),
        .jtag_axi_awlen    ( jtag_axi_awlen    ),
        .jtag_axi_awsize   ( jtag_axi_awsize   ),
        .jtag_axi_awburst  ( jtag_axi_awburst  ),
        .jtag_axi_awlock   ( jtag_axi_awlock   ),
        .jtag_axi_awcache  ( jtag_axi_awcache  ),
        .jtag_axi_awprot   ( jtag_axi_awprot   ),
        .jtag_axi_awqos    ( jtag_axi_awqos    ),
        .jtag_axi_awvalid  ( jtag_axi_awvalid  ),
        .jtag_axi_awready  ( jtag_axi_awready  ),
        .jtag_axi_awregion ( jtag_axi_awregion ),
        .jtag_axi_wdata    ( jtag_axi_wdata    ),
        .jtag_axi_wstrb    ( jtag_axi_wstrb    ),
        .jtag_axi_wlast    ( jtag_axi_wlast    ),
        .jtag_axi_wvalid   ( jtag_axi_wvalid   ),
        .jtag_axi_wready   ( jtag_axi_wready   ),
        .jtag_axi_bid      ( jtag_axi_bid      ),
        .jtag_axi_bresp    ( jtag_axi_bresp    ),
        .jtag_axi_bvalid   ( jtag_axi_bvalid   ),
        .jtag_axi_bready   ( jtag_axi_bready   ),
        .jtag_axi_araddr   ( jtag_axi_araddr   ),
        .jtag_axi_arlen    ( jtag_axi_arlen    ),
        .jtag_axi_arsize   ( jtag_axi_arsize   ),
        .jtag_axi_arburst  ( jtag_axi_arburst  ),
        .jtag_axi_arlock   ( jtag_axi_arlock   ),
        .jtag_axi_arcache  ( jtag_axi_arcache  ),
        .jtag_axi_arprot   ( jtag_axi_arprot   ),
        .jtag_axi_arqos    ( jtag_axi_arqos    ),
        .jtag_axi_arvalid  ( jtag_axi_arvalid  ),
        .jtag_axi_arready  ( jtag_axi_arready  ),
        .jtag_axi_arid     ( jtag_axi_arid     ),
        .jtag_axi_arregion ( jtag_axi_arregion ),
        .jtag_axi_rid      ( jtag_axi_rid      ),
        .jtag_axi_rdata    ( jtag_axi_rdata    ),
        .jtag_axi_rresp    ( jtag_axi_rresp    ),
        .jtag_axi_rlast    ( jtag_axi_rlast    ),
        .jtag_axi_rvalid   ( jtag_axi_rvalid   ),
        .jtag_axi_rready   ( jtag_axi_rready   )
    );

    /////////
    // VIP //
    /////////
    typedef axi_mst_agent #(0, AW, 32, 32, IW, IW, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1) mst_t;
    mst_t mst;

    axi_vip_v1_1_19_top #(
        .C_AXI_PROTOCOL(0), .C_AXI_INTERFACE_MODE(0), .C_AXI_ADDR_WIDTH(AW), .C_AXI_WDATA_WIDTH(32),
        .C_AXI_RDATA_WIDTH(32), .C_AXI_WID_WIDTH(IW), .C_AXI_RID_WIDTH(IW)
    ) vip (
        .aclk(clk), .aclken(1'b1), .aresetn(locked),
        .m_axi_awid(jtag_axi_awid), .m_axi_awaddr(jtag_axi_awaddr), .m_axi_awlen(jtag_axi_awlen),
        .m_axi_awsize(jtag_axi_awsize), .m_axi_awburst(jtag_axi_awburst), .m_axi_awlock(jtag_axi_awlock),
        .m_axi_awcache(jtag_axi_awcache), .m_axi_awprot(jtag_axi_awprot), .m_axi_awregion(jtag_axi_awregion),
        .m_axi_awqos(jtag_axi_awqos), .m_axi_awvalid(jtag_axi_awvalid), .m_axi_awready(jtag_axi_awready),
        .m_axi_wdata(jtag_axi_wdata), .m_axi_wstrb(jtag_axi_wstrb), .m_axi_wlast(jtag_axi_wlast),
        .m_axi_wvalid(jtag_axi_wvalid), .m_axi_wready(jtag_axi_wready), .m_axi_bid(jtag_axi_bid),
        .m_axi_bresp(jtag_axi_bresp), .m_axi_bvalid(jtag_axi_bvalid), .m_axi_bready(jtag_axi_bready),
        .m_axi_arid(jtag_axi_arid), .m_axi_araddr(jtag_axi_araddr), .m_axi_arlen(jtag_axi_arlen),
        .m_axi_arsize(jtag_axi_arsize), .m_axi_arburst(jtag_axi_arburst), .m_axi_arlock(jtag_axi_arlock),
        .m_axi_arcache(jtag_axi_arcache), .m_axi_arprot(jtag_axi_arprot), .m_axi_arregion(jtag_axi_arregion),
        .m_axi_arqos(jtag_axi_arqos), .m_axi_arvalid(jtag_axi_arvalid), .m_axi_arready(jtag_axi_arready),
        .m_axi_rid(jtag_axi_rid), .m_axi_rdata(jtag_axi_rdata), .m_axi_rresp(jtag_axi_rresp),
        .m_axi_rlast(jtag_axi_rlast), .m_axi_rvalid(jtag_axi_rvalid), .m_axi_rready(jtag_axi_rready)
    );

    ////////////////
    // UART, GPIO //
    ////////////////
    string captured = "", golden = "", stimulus = "";
    bit passed = 1'b0;

    function automatic bit ends_with(string s, string suffix);
        return s.len() >= suffix.len() && s.substr(s.len() - suffix.len(), s.len() - 1) == suffix;
    endfunction

    // 8N1 decoder, each bit sampled at mid-period
    initial forever begin
        byte c;
        @(negedge uart_tx);
        repeat (CPB / 2) @(posedge clk);
        if (uart_tx) continue;
        for (int i = 0; i < 8; i++) begin
            repeat (CPB) @(posedge clk);
            c[i] = uart_tx;
        end
        repeat (CPB) @(posedge clk);
        captured = {captured, string'(c)};
        passed |= ends_with(captured, golden);
        if (stimulus.len() && ends_with(captured, PROMPT))
            fork send(stimulus); join_none
    end

    task automatic send(string s);
        foreach (s[k])
            for (int i = 0; i < 10; i++) begin
                uart_rx <= i == 0 ? 1'b0 : i == 9 ? 1'b1 : s[k][i-1];
                repeat (CPB) @(posedge clk);
            end
    endtask

    initial forever begin
        repeat (GPIO_TOGGLE_PERIOD) @(posedge clk);
        gpio_in[0] <= ~gpio_in[0];
    end

    //////////
    // Test //
    //////////
    typedef byte unsigned bytes_t[$];

    // A string cannot hold NUL bytes: the binary is read as bytes
    function automatic bytes_t read_bytes(string path);
        int fd = $fopen(path, "rb");
        int c;
        if (!fd) $fatal(1, "[EMB] cannot open %s", path);
        while ((c = $fgetc(fd)) != -1) read_bytes.push_back(c);
        $fclose(fd);
    endfunction

    function automatic string read_file(string path);
        bytes_t b = read_bytes(path);
        read_file = "";
        foreach (b[i]) read_file = {read_file, string'(b[i])};
    endfunction

    // One little-endian word per single-beat write, ascending addresses (jtag2axi_load_binary.tcl)
    task automatic load(bytes_t image);
        axi_transaction wr;
        for (int i = 0; i < image.size(); i += 4) begin
            bit [31:0] w = '0;
            for (int b = 0; b < 4 && i + b < image.size(); b++) w[8*b +: 8] = image[i + b];
            wr = mst.wr_driver.create_transaction("load");
            wr.set_write_cmd(i, XIL_AXI_BURST_TYPE_INCR, 0, 0, XIL_AXI_SIZE_4BYTE);
            wr.set_data_block(w);
            wr.set_driver_return_item_policy(XIL_AXI_PAYLOAD_RETURN);
            mst.wr_driver.send(wr);
            mst.wr_driver.wait_rsp(wr);
            if (wr.get_bresp() != XIL_AXI_RESP_OKAY) $fatal(1, "[EMB] load: bresp %0d @%h", wr.get_bresp(), i);
        end
    endtask

    initial begin
        string path;
        bytes_t image;
        automatic longint cycles = 0;
        if (!$value$plusargs("BIN=%s", path)) $fatal(1, "[EMB] +BIN missing");
        image = read_bytes(path);
        if (!$value$plusargs("GOLDEN=%s", path)) $fatal(1, "[EMB] +GOLDEN missing");
        golden = read_file(path);
        // scanf("%s") ends the token on whitespace: send exactly one '\n'
        if ($value$plusargs("STIMULUS=%s", path)) begin
            stimulus = read_file(path);
            while (stimulus.len() && (stimulus[stimulus.len()-1] inside {"\n", "\r"}))
                stimulus = stimulus.substr(0, stimulus.len() - 2);
            stimulus = {stimulus, "\n"};
        end

        mst = new("mst", vip.IF);
        repeat (32) @(posedge clk);
        locked <= 1'b1;
        repeat (16) @(posedge clk);
        mst.start_master();
        load(image);
        $display("[EMB] loaded %0d bytes at %t", image.size(), $time);
        vio_resetn <= 1'b1;

        while (!passed && cycles < `SIM_MAX_CYCLES) begin
            @(posedge clk);
            cycles++;
        end
        $display("[EMB] %0d cycles%s", cycles, passed ? string'("") : string'(", SIM_MAX_CYCLES reached"));
        $display("[EMB] captured: \"%s\"", captured);
        $display("[EMB] %s", passed ? "PASS" : "FAIL");
        $finish;
    end

endmodule
