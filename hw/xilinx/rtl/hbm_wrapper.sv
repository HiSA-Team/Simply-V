// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description: This module is a wrapper for the HBM IP.
//              It includes :
//                 - A datawidth converter to increase the datawidth to 256 bit
//                 - A HBM IP
//
//              It has the following sub-architecture
//
//
//   ADDR: PHYSICAL_ADDR_WIDTH    ____________  ADDR: PHYSICAL_ADDR_WIDTH       ADDR: 33 bit    ____________
//   DATA: XLEN                  |   Dwidth   | DATA: 256 bit                   DATA: 256 bit  |            |
// ----------------------------->| Converter  |----------------------------------------------->|   HBM IP   |
//                               |____________|                                                |____________|
//
// NOTE: The HBM IP can be imported only with boards supporting it (au280, au50)
// NOTE: For now, we use only one AXI port connected to all the HBM space.

// TODO: update description adding the AXILITE interfaces for the two HBM stacks

`include "uninasoc_apb.svh"

module hbm_wrapper #(
    parameter int unsigned    LOCAL_DATA_WIDTH  = 32, // These are MBUS WIDTHS
    parameter int unsigned    LOCAL_ADDR_WIDTH  = 32,
    parameter int unsigned    LOCAL_ID_WIDTH    = 32
) (
    // Clocks and resets
    // Reference clock used by the HBM IP internally to drive PLL for clocking the memory controllers and stacks
    input logic hbm_ref_clk_i,

    // Clock and reset for AXI4 slaves
    input logic clock_i,
    input logic reset_ni,

    // Clock and reset for Axilite (CSR) slaves
    input logic csr_clock_i,
    input logic csr_reset_ni,

    // AXI4 Slave port 0
    `DEFINE_AXI_SLAVE_PORTS(s0, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH),

    // Axilite Slave port to access HBM APB interface for stack 0
    `DEFINE_AXILITE_SLAVE_PORTS(s0, 32, 22, LOCAL_ID_WIDTH),

    // Axilite Slave port to access HBM APB interface for stack 1
    `DEFINE_AXILITE_SLAVE_PORTS(s1, 32, 22, LOCAL_ID_WIDTH)
);

    // HBM local parameters
    localparam HBM_ADDRESS_WIDTH = 33;
    localparam HBM_DATA_WIDTH = 256;
    localparam HBM_ID_WIDTH = 6;

    localparam APB_ADDRESS_WIDTH = 22;
    localparam APB_DATA_WIDTH    = 32;
    localparam APB_NUM_SLAVE     = 1;

    // HBM 33-bits address signals
    logic [HBM_ADDRESS_WIDTH-1:0] hbm_axi_awaddr;
    logic [HBM_ADDRESS_WIDTH-1:0] hbm_axi_araddr;

    // AXI4 bus from dwith converter to HBM IP AXI4 interface
    `DECLARE_AXI_BUS(dwidth_conv_to_hbm, HBM_DATA_WIDTH, LOCAL_ADDR_WIDTH, HBM_ID_WIDTH)

    // APB bus from axilite to APB converter to HBM IP APB interface for stack 0
    `DECLARE_APB_BUS(prot_conv_to_hbm_stack_0, APB_DATA_WIDTH, APB_ADDRESS_WIDTH, APB_NUM_SLAVE)

    // APB bus from axilite to APB converter to HBM IP APB interface for stack 1
    `DECLARE_APB_BUS(prot_conv_to_hbm_stack_1, APB_DATA_WIDTH, APB_ADDRESS_WIDTH, APB_NUM_SLAVE)

    // AXI dwith converter from XLEN bit (global AXI data width) to 256 bit (AXI user interface HBM data width)
    xlnx_axi_dwidth_to256_converter axi_dwidth_conv_u (
        .s_axi_aclk     ( clock_i      ),
        .s_axi_aresetn  ( reset_ni     ),

        // Slave from MBUS
        .s_axi_awid     ( s0_axi_awid     ),
        .s_axi_awaddr   ( s0_axi_awaddr   ),
        .s_axi_awlen    ( s0_axi_awlen    ),
        .s_axi_awsize   ( s0_axi_awsize   ),
        .s_axi_awburst  ( s0_axi_awburst  ),
        .s_axi_awvalid  ( s0_axi_awvalid  ),
        .s_axi_awready  ( s0_axi_awready  ),
        .s_axi_wdata    ( s0_axi_wdata    ),
        .s_axi_wstrb    ( s0_axi_wstrb    ),
        .s_axi_wlast    ( s0_axi_wlast    ),
        .s_axi_wvalid   ( s0_axi_wvalid   ),
        .s_axi_wready   ( s0_axi_wready   ),
        .s_axi_bid      ( s0_axi_bid      ),
        .s_axi_bresp    ( s0_axi_bresp    ),
        .s_axi_bvalid   ( s0_axi_bvalid   ),
        .s_axi_bready   ( s0_axi_bready   ),
        .s_axi_arid     ( s0_axi_arid     ),
        .s_axi_araddr   ( s0_axi_araddr   ),
        .s_axi_arlen    ( s0_axi_arlen    ),
        .s_axi_arsize   ( s0_axi_arsize   ),
        .s_axi_arburst  ( s0_axi_arburst  ),
        .s_axi_arvalid  ( s0_axi_arvalid  ),
        .s_axi_arready  ( s0_axi_arready  ),
        .s_axi_rid      ( s0_axi_rid      ),
        .s_axi_rdata    ( s0_axi_rdata    ),
        .s_axi_rresp    ( s0_axi_rresp    ),
        .s_axi_rlast    ( s0_axi_rlast    ),
        .s_axi_rvalid   ( s0_axi_rvalid   ),
        .s_axi_rready   ( s0_axi_rready   ),
        .s_axi_awlock   ( s0_axi_awlock   ),
        .s_axi_awcache  ( s0_axi_awcache  ),
        .s_axi_awprot   ( s0_axi_awprot   ),
        .s_axi_awqos    ( s0_axi_awqos    ),
        .s_axi_awregion ( s0_axi_awregion ),
        .s_axi_arlock   ( s0_axi_arlock   ),
        .s_axi_arcache  ( s0_axi_arcache  ),
        .s_axi_arprot   ( s0_axi_arprot   ),
        .s_axi_arqos    ( s0_axi_arqos    ),
        .s_axi_arregion ( s0_axi_arregion ),


        // Master to HBM
        // .m_axi_awid     ( dwidth_conv_to_hbm_axi_awid    ),
        .m_axi_awaddr   ( dwidth_conv_to_hbm_axi_awaddr  ),
        .m_axi_awlen    ( dwidth_conv_to_hbm_axi_awlen   ),
        .m_axi_awsize   ( dwidth_conv_to_hbm_axi_awsize  ),
        .m_axi_awburst  ( dwidth_conv_to_hbm_axi_awburst ),
        .m_axi_awlock   ( dwidth_conv_to_hbm_axi_awlock  ),
        .m_axi_awcache  ( dwidth_conv_to_hbm_axi_awcache ),
        .m_axi_awprot   ( dwidth_conv_to_hbm_axi_awprot  ),
        .m_axi_awqos    ( dwidth_conv_to_hbm_axi_awqos   ),
        .m_axi_awvalid  ( dwidth_conv_to_hbm_axi_awvalid ),
        .m_axi_awready  ( dwidth_conv_to_hbm_axi_awready ),
        .m_axi_wdata    ( dwidth_conv_to_hbm_axi_wdata   ),
        .m_axi_wstrb    ( dwidth_conv_to_hbm_axi_wstrb   ),
        .m_axi_wlast    ( dwidth_conv_to_hbm_axi_wlast   ),
        .m_axi_wvalid   ( dwidth_conv_to_hbm_axi_wvalid  ),
        .m_axi_wready   ( dwidth_conv_to_hbm_axi_wready  ),
        // .m_axi_bid      ( dwidth_conv_to_hbm_axi_bid     ),
        .m_axi_bresp    ( dwidth_conv_to_hbm_axi_bresp   ),
        .m_axi_bvalid   ( dwidth_conv_to_hbm_axi_bvalid  ),
        .m_axi_bready   ( dwidth_conv_to_hbm_axi_bready  ),
        // .m_axi_arid     ( dwidth_conv_to_hbm_axi_arid    ),
        .m_axi_araddr   ( dwidth_conv_to_hbm_axi_araddr  ),
        .m_axi_arlen    ( dwidth_conv_to_hbm_axi_arlen   ),
        .m_axi_arsize   ( dwidth_conv_to_hbm_axi_arsize  ),
        .m_axi_arburst  ( dwidth_conv_to_hbm_axi_arburst ),
        .m_axi_arlock   ( dwidth_conv_to_hbm_axi_arlock  ),
        .m_axi_arcache  ( dwidth_conv_to_hbm_axi_arcache ),
        .m_axi_arprot   ( dwidth_conv_to_hbm_axi_arprot  ),
        .m_axi_arqos    ( dwidth_conv_to_hbm_axi_arqos   ),
        .m_axi_arvalid  ( dwidth_conv_to_hbm_axi_arvalid ),
        .m_axi_arready  ( dwidth_conv_to_hbm_axi_arready ),
        // .m_axi_rid      ( dwidth_conv_to_hbm_axi_rid     ),
        .m_axi_rdata    ( dwidth_conv_to_hbm_axi_rdata   ),
        .m_axi_rresp    ( dwidth_conv_to_hbm_axi_rresp   ),
        .m_axi_rlast    ( dwidth_conv_to_hbm_axi_rlast   ),
        .m_axi_rvalid   ( dwidth_conv_to_hbm_axi_rvalid  ),
        .m_axi_rready   ( dwidth_conv_to_hbm_axi_rready  )

    );

    // IDs to 0 from the dwidth conv
    // TODO: check if IDs have a particular meaning in HBM (maybe the switch uses them)
    assign dwidth_conv_to_hbm_axi_awid = '0;
    assign dwidth_conv_to_hbm_axi_bid  = '0;
    assign dwidth_conv_to_hbm_axi_arid = '0;
    assign dwidth_conv_to_hbm_axi_rid  = '0;

    xlnx_axilite_to_apb_converter axilite_to_apb_stack_0_conv_u (
        .s_axi_aclk    ( csr_clock_i  ),
        .s_axi_aresetn ( csr_reset_ni ),

        .s_axi_awaddr   ( s0_axilite_awaddr   ),
        .s_axi_awvalid  ( s0_axilite_awvalid  ),
        .s_axi_awready  ( s0_axilite_awready  ),
        .s_axi_wdata    ( s0_axilite_wdata    ),
        .s_axi_wvalid   ( s0_axilite_wvalid   ),
        .s_axi_wready   ( s0_axilite_wready   ),
        .s_axi_bresp    ( s0_axilite_bresp    ),
        .s_axi_bvalid   ( s0_axilite_bvalid   ),
        .s_axi_bready   ( s0_axilite_bready   ),
        .s_axi_araddr   ( s0_axilite_araddr   ),
        .s_axi_arvalid  ( s0_axilite_arvalid  ),
        .s_axi_arready  ( s0_axilite_arready  ),
        .s_axi_rdata    ( s0_axilite_rdata    ),
        .s_axi_rresp    ( s0_axilite_rresp    ),
        .s_axi_rvalid   ( s0_axilite_rvalid   ),
        .s_axi_rready   ( s0_axilite_rready   ),

        .m_apb_paddr    ( prot_conv_to_hbm_stack_0_apb_paddr   ),
        .m_apb_pwdata   ( prot_conv_to_hbm_stack_0_apb_pwdata  ),
        .m_apb_prdata   ( prot_conv_to_hbm_stack_0_apb_prdata  ),
        .m_apb_penable  ( prot_conv_to_hbm_stack_0_apb_penable ),
        .m_apb_psel     ( prot_conv_to_hbm_stack_0_apb_psel    ),
        .m_apb_pwrite   ( prot_conv_to_hbm_stack_0_apb_pwrite  ),
        .m_apb_pready   ( prot_conv_to_hbm_stack_0_apb_pready  ),
        .m_apb_pslverr  ( prot_conv_to_hbm_stack_0_apb_pslverr )
    );

    xlnx_axilite_to_apb_converter axilite_to_apb_stack_1_conv_u (
        .s_axi_aclk    ( csr_clock_i  ),
        .s_axi_aresetn ( csr_reset_ni ),

        .s_axi_awaddr   ( s1_axilite_awaddr   ),
        .s_axi_awvalid  ( s1_axilite_awvalid  ),
        .s_axi_awready  ( s1_axilite_awready  ),
        .s_axi_wdata    ( s1_axilite_wdata    ),
        .s_axi_wvalid   ( s1_axilite_wvalid   ),
        .s_axi_wready   ( s1_axilite_wready   ),
        .s_axi_bresp    ( s1_axilite_bresp    ),
        .s_axi_bvalid   ( s1_axilite_bvalid   ),
        .s_axi_bready   ( s1_axilite_bready   ),
        .s_axi_araddr   ( s1_axilite_araddr   ),
        .s_axi_arvalid  ( s1_axilite_arvalid  ),
        .s_axi_arready  ( s1_axilite_arready  ),
        .s_axi_rdata    ( s1_axilite_rdata    ),
        .s_axi_rresp    ( s1_axilite_rresp    ),
        .s_axi_rvalid   ( s1_axilite_rvalid   ),
        .s_axi_rready   ( s1_axilite_rready   ),

        .m_apb_paddr    ( prot_conv_to_hbm_stack_1_apb_paddr   ),
        .m_apb_pwdata   ( prot_conv_to_hbm_stack_1_apb_pwdata  ),
        .m_apb_prdata   ( prot_conv_to_hbm_stack_1_apb_prdata  ),
        .m_apb_penable  ( prot_conv_to_hbm_stack_1_apb_penable ),
        .m_apb_psel     ( prot_conv_to_hbm_stack_1_apb_psel    ),
        .m_apb_pwrite   ( prot_conv_to_hbm_stack_1_apb_pwrite  ),
        .m_apb_pready   ( prot_conv_to_hbm_stack_1_apb_pready  ),
        .m_apb_pslverr  ( prot_conv_to_hbm_stack_1_apb_pslverr )
    );

    // Map HBM address signals
    // Zero extend them if the address width is 32, otherwise clip them down.
    assign hbm_axi_awaddr = (LOCAL_ADDR_WIDTH == 32) ? { 1'b0, dwidth_conv_to_hbm_axi_awaddr } : dwidth_conv_to_hbm_axi_awaddr[HBM_ADDRESS_WIDTH-1:0];
    assign hbm_axi_araddr = (LOCAL_ADDR_WIDTH == 32) ? { 1'b0, dwidth_conv_to_hbm_axi_araddr } : dwidth_conv_to_hbm_axi_araddr[HBM_ADDRESS_WIDTH-1:0];

    // HBM IP
    xlnx_hbm hbm_u (
        // Clocks and resets
        .HBM_REF_CLK_0   ( hbm_ref_clk_i ),    // PLL reference clock stack 0 (100 MHz)
        .HBM_REF_CLK_1   ( hbm_ref_clk_i ),    // PLL reference clock stack 1 (100 MHz)
        .AXI_00_ACLK     ( clock_i       ),    // AXI slave 00 aclock
        .AXI_00_ARESET_N ( reset_ni      ),    // AXI slave 00 resetn

        // AXI4 slave 00
        // NOTE: The documentation (PG276) states that must be fixed: AxSIZE = 0x5 and AxLEN = 0x1 (minimum). This should be done by the dwidth conv
        .AXI_00_ARADDR  ( hbm_axi_araddr                 ),    // input [32:0]
        .AXI_00_ARBURST ( dwidth_conv_to_hbm_axi_arburst ),    // input [1:0]
        .AXI_00_ARID    ( dwidth_conv_to_hbm_axi_arid    ),    // input [5:0]
        .AXI_00_ARLEN   ( dwidth_conv_to_hbm_axi_arlen   ),    // input [3:0]
        .AXI_00_ARREADY ( dwidth_conv_to_hbm_axi_arready ),    // output
        .AXI_00_ARSIZE  ( dwidth_conv_to_hbm_axi_arsize  ),    // input [2:0]
        .AXI_00_ARVALID ( dwidth_conv_to_hbm_axi_arvalid ),    // input

        .AXI_00_AWADDR  ( hbm_axi_awaddr                 ),    // input [32:0]
        .AXI_00_AWBURST ( dwidth_conv_to_hbm_axi_awburst ),    // input [1:0]
        .AXI_00_AWID    ( dwidth_conv_to_hbm_axi_awid    ),    // input [5:0]
        .AXI_00_AWLEN   ( dwidth_conv_to_hbm_axi_awlen   ),    // input [3:0]
        .AXI_00_AWREADY ( dwidth_conv_to_hbm_axi_awready ),    // output
        .AXI_00_AWSIZE  ( dwidth_conv_to_hbm_axi_awsize  ),    // input [2:0]
        .AXI_00_AWVALID ( dwidth_conv_to_hbm_axi_awvalid ),    // input

        .AXI_00_RDATA   ( dwidth_conv_to_hbm_axi_rdata   ),    // output [255:0]
        .AXI_00_RID     ( dwidth_conv_to_hbm_axi_rid     ),    // output [5:0]
        .AXI_00_RLAST   ( dwidth_conv_to_hbm_axi_rlast   ),    // output
        .AXI_00_RREADY  ( dwidth_conv_to_hbm_axi_rready  ),    // input
        .AXI_00_RRESP   ( dwidth_conv_to_hbm_axi_rresp   ),    // output [1:0]
        .AXI_00_RVALID  ( dwidth_conv_to_hbm_axi_rvalid  ),    // output

        .AXI_00_WDATA   ( dwidth_conv_to_hbm_axi_wdata   ),    // input [255:0]
        .AXI_00_WLAST   ( dwidth_conv_to_hbm_axi_wlast   ),    // input
        .AXI_00_WREADY  ( dwidth_conv_to_hbm_axi_wready  ),    // output
        .AXI_00_WSTRB   ( dwidth_conv_to_hbm_axi_wstrb   ),    // input [31:0]
        .AXI_00_WVALID  ( dwidth_conv_to_hbm_axi_wvalid  ),    // input

        .AXI_00_BID     ( dwidth_conv_to_hbm_axi_bid     ),    // output [5:0]
        .AXI_00_BREADY  ( dwidth_conv_to_hbm_axi_bready  ),    // input [2:0]
        .AXI_00_BRESP   ( dwidth_conv_to_hbm_axi_bresp   ),    // output
        .AXI_00_BVALID  ( dwidth_conv_to_hbm_axi_bvalid  ),    // output


        .AXI_00_WDATA_PARITY ( '0             ), // input  [31:0]
        .AXI_00_RDATA_PARITY ( /* empty */    ), // output [31:0]

        // APB interface to access Memory Controller (MC) CSR (unused)
        // Stack 0
        .APB_0_PCLK          ( csr_clock_i    ), // input
        .APB_0_PRESET_N      ( csr_reset_ni   ), // input
        .APB_0_PWDATA        ( prot_conv_to_hbm_stack_0_apb_pwdata  ), // input [31:0]
        .APB_0_PADDR         ( prot_conv_to_hbm_stack_0_apb_paddr   ), // input [21:0]
        .APB_0_PENABLE       ( prot_conv_to_hbm_stack_0_apb_penable ), // input
        .APB_0_PSEL          ( prot_conv_to_hbm_stack_0_apb_psel    ), // input
        .APB_0_PWRITE        ( prot_conv_to_hbm_stack_0_apb_pwrite  ), // input
        .APB_0_PRDATA        ( prot_conv_to_hbm_stack_0_apb_prdata  ), // output [31:0]
        .APB_0_PREADY        ( prot_conv_to_hbm_stack_0_apb_pready  ), // output
        .APB_0_PSLVERR       ( prot_conv_to_hbm_stack_0_apb_pslverr ), // output
        .apb_complete_0      ( /* empty */    ), // output

        .DRAM_0_STAT_CATTRIP ( /* empty */    ), // output
        .DRAM_0_STAT_TEMP    ( /* empty */    ),  // output [6:0]

        // Stack 1
        .APB_1_PCLK          ( csr_clock_i    ), // input
        .APB_1_PRESET_N      ( csr_reset_ni   ), // input
        .APB_1_PWDATA        ( prot_conv_to_hbm_stack_1_apb_pwdata  ), // input [31:0]
        .APB_1_PADDR         ( prot_conv_to_hbm_stack_1_apb_paddr   ), // input [21:0]
        .APB_1_PENABLE       ( prot_conv_to_hbm_stack_1_apb_penable ), // input
        .APB_1_PSEL          ( prot_conv_to_hbm_stack_1_apb_psel    ), // input
        .APB_1_PWRITE        ( prot_conv_to_hbm_stack_1_apb_pwrite  ), // input
        .APB_1_PRDATA        ( prot_conv_to_hbm_stack_1_apb_prdata  ), // output [31:0]
        .APB_1_PREADY        ( prot_conv_to_hbm_stack_1_apb_pready  ), // output
        .APB_1_PSLVERR       ( prot_conv_to_hbm_stack_1_apb_pslverr ), // output
        .apb_complete_1      ( /* empty */    ), // output

        .DRAM_1_STAT_CATTRIP ( /* empty */    ), // output
        .DRAM_1_STAT_TEMP    ( /* empty */    )  // output [6:0]
    );

endmodule : hbm_wrapper

