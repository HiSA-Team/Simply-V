// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Author: Valerio Di Domenico <valerio.didomenico@unina.it>
// Description: This module is a wrapper for a single DDR4 channel.
//              It includes :
//                 - A clock converter to increase the frequency to 300 MHz
//                 - An optional System Cache (enabled if ENABLE_CACHE=1)
//                 - A datawidth converter to increase the datawidth to 512 bit (enabled if ENABLE_CACHE=0)
//                 - A DDR4 (MIG) IP
//
//              Depending on the ENABLE_CACHE parameter, the architecture
//              instantiates either the System Cache (ENABLE_CACHE=1) or a
//              direct Data Width Converter (ENABLE_CACHE=0) before connecting
//              to the Clock Converter and DDR4 (MIG).
//
//              It has the following sub-architecture:
//                                                 _____________
//                                                |   System    |
//   Main Clock Domain        /------------------>|    Cache    |---->|  Main Clock Domain                     DDR4CH<n> Clock Domain
//   ADDR: MBUS_ADDR_WIDTH    | ENABLE_CACHE = 1  |_____________|     |  ADDR: MBUS_ADDR_WIDTH  ____________   ADDR: 34 bit     ____________
//   DATA: MBUS_DATA_WIDTH    |                                       |  DATA: 512             |   Clock    |  DATA: 512 bit   |            |
// ------------------------ ->|                                       |----------------------->| Converter  |----------------->| DDR4 (MIG) |
//         s_axi              |                     _____________     |      to_clk_conv       |____________| clk_conv_to_ddr4 |____________|
//                            | ENABLE_CACHE = 0   |    Dwidth   |    |
//                            \------------------->|  Converter  |--->|
//                                                 |_____________|


`include "uninasoc_pcie.svh"
`include "uninasoc_ddr4.svh"

module ddr4_channel_wrapper # (
    parameter int unsigned    ENABLE_CACHE      = 0,
    parameter int unsigned    LOCAL_DATA_WIDTH  = 32,
    parameter int unsigned    LOCAL_ADDR_WIDTH  = 32,
    parameter int unsigned    LOCAL_ID_WIDTH    = 32
) (
    // SoC clock and reset
    input logic clock_i,
    input logic reset_ni,

    // DDR4 CH0 clock and reset
    input logic clk_300mhz_0_p_i,
    input logic clk_300mhz_0_n_i,

    // DDR4 channel interface (to PHYs)
    `DEFINE_DDR4_PORTS(x),

    // AXI-lite CSR interface
    `DEFINE_AXILITE_SLAVE_PORTS(s_ctrl, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH),

    // AXI4 Slave interface
    `DEFINE_AXI_SLAVE_PORTS(s, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

);

    // DDR4 local parameters
    localparam DDR4_CHANNEL_ADDRESS_WIDTH = 34;
    localparam DDR4_CHANNEL_DATA_WIDTH = 512;

    // DDR4 sys reset - it is active high
    logic ddr4_reset = 1'b1;

    always @(posedge clock_i or negedge reset_ni) begin
        if (reset_ni == 1'b0) begin
            ddr4_reset <= 1'b1;
        end else begin
            ddr4_reset <= 1'b0;
        end
    end

    // DDR4 output clk and rst
    logic ddr_clk;
    logic ddr_rst;

    // DDR4 34-bits address signals
    logic [DDR4_CHANNEL_ADDRESS_WIDTH-1:0] ddr4_axi_awaddr;
    logic [DDR4_CHANNEL_ADDRESS_WIDTH-1:0] ddr4_axi_araddr;

    // AXI bus from the cache to the clock converter
    `DECLARE_AXI_BUS(to_clk_conv, DDR4_CHANNEL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    // AXI bus from the clock converter to the dwidth converter
    `DECLARE_AXI_BUS(clk_conv_to_dwidth_conv, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    // AXI bus from the cache to the DDR4
    `DECLARE_AXI_BUS(clk_conv_to_ddr4, DDR4_CHANNEL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    generate
    if (ENABLE_CACHE == 1 ) begin : with_cache

            xlnx_system_cache_0 system_cache_u (

                .ACLK               ( clock_i                 ), // input wire ACLK
                .ARESETN            ( reset_ni                ), // input wire ARESETN
                .Initializing       ( /* empty */             ), // output wire Initializing
                .S0_AXI_GEN_AWID    ( s_axi_awid              ), // input wire [2 : 0] S0_AXI_GEN_AWID
                .S0_AXI_GEN_AWADDR  ( s_axi_awaddr            ), // input wire [31 : 0] S0_AXI_GEN_AWADDR
                .S0_AXI_GEN_AWLEN   ( s_axi_awlen             ), // input wire [7 : 0] S0_AXI_GEN_AWLEN
                .S0_AXI_GEN_AWSIZE  ( s_axi_awsize            ), // input wire [2 : 0] S0_AXI_GEN_AWSIZE
                .S0_AXI_GEN_AWBURST ( s_axi_awburst           ), // input wire [1 : 0] S0_AXI_GEN_AWBURST
                .S0_AXI_GEN_AWLOCK  ( s_axi_awlock            ), // input wire S0_AXI_GEN_AWLOCK
                .S0_AXI_GEN_AWCACHE ( s_axi_awcache           ), // input wire [3 : 0] S0_AXI_GEN_AWCACHE
                .S0_AXI_GEN_AWPROT  ( s_axi_awprot            ), // input wire [2 : 0] S0_AXI_GEN_AWPROT
                .S0_AXI_GEN_AWQOS   ( s_axi_awqos             ), // input wire [3 : 0] S0_AXI_GEN_AWQOS
                .S0_AXI_GEN_AWVALID ( s_axi_awvalid           ), // input wire S0_AXI_GEN_AWVALID
                .S0_AXI_GEN_AWREADY ( s_axi_awready           ), // output wire S0_AXI_GEN_AWREADY
                .S0_AXI_GEN_AWUSER  ( s_axi_awuser            ), // input wire [31 : 0] S0_AXI_GEN_AWUSER
                .S0_AXI_GEN_WDATA   ( s_axi_wdata             ), // input wire [511 : 0] S0_AXI_GEN_WDATA
                .S0_AXI_GEN_WSTRB   ( s_axi_wstrb             ), // input wire [63 : 0] S0_AXI_GEN_WSTRB
                .S0_AXI_GEN_WLAST   ( s_axi_wlast             ), // input wire S0_AXI_GEN_WLAST
                .S0_AXI_GEN_WVALID  ( s_axi_wvalid            ), // input wire S0_AXI_GEN_WVALID
                .S0_AXI_GEN_WREADY  ( s_axi_wready            ), // output wire S0_AXI_GEN_WREADY
                .S0_AXI_GEN_BRESP   ( s_axi_bresp             ), // output wire [1 : 0] S0_AXI_GEN_BRESP
                .S0_AXI_GEN_BID     ( s_axi_bid               ), // output wire [2 : 0] S0_AXI_GEN_BID
                .S0_AXI_GEN_BVALID  ( s_axi_bvalid            ), // output wire S0_AXI_GEN_BVALID
                .S0_AXI_GEN_BREADY  ( s_axi_bready            ), // input wire S0_AXI_GEN_BREADY
                .S0_AXI_GEN_ARID    ( s_axi_arid              ), // input wire [2 : 0] S0_AXI_GEN_ARID
                .S0_AXI_GEN_ARADDR  ( s_axi_araddr            ), // input wire [31 : 0] S0_AXI_GEN_ARADDR
                .S0_AXI_GEN_ARLEN   ( s_axi_arlen             ), // input wire [7 : 0] S0_AXI_GEN_ARLEN
                .S0_AXI_GEN_ARSIZE  ( s_axi_arsize            ), // input wire [2 : 0] S0_AXI_GEN_ARSIZE
                .S0_AXI_GEN_ARBURST ( s_axi_arburst           ), // input wire [1 : 0] S0_AXI_GEN_ARBURST
                .S0_AXI_GEN_ARLOCK  ( s_axi_arlock            ), // input wire S0_AXI_GEN_ARLOCK
                .S0_AXI_GEN_ARCACHE ( s_axi_arcache           ), // input wire [3 : 0] S0_AXI_GEN_ARCACHE
                .S0_AXI_GEN_ARPROT  ( s_axi_arprot            ), // input wire [2 : 0] S0_AXI_GEN_ARPROT
                .S0_AXI_GEN_ARQOS   ( s_axi_arqos             ), // input wire [3 : 0] S0_AXI_GEN_ARQOS
                .S0_AXI_GEN_ARVALID ( s_axi_arvalid           ), // input wire S0_AXI_GEN_ARVALID
                .S0_AXI_GEN_ARREADY ( s_axi_arready           ), // output wire S0_AXI_GEN_ARREADY
                .S0_AXI_GEN_ARUSER  ( s_axi_aruser            ), // input wire [31 : 0] S0_AXI_GEN_ARUSER
                .S0_AXI_GEN_RID     ( s_axi_rid               ), // output wire [2 : 0] S0_AXI_GEN_RID
                .S0_AXI_GEN_RDATA   ( s_axi_rdata             ), // output wire [511 : 0] S0_AXI_GEN_RDATA
                .S0_AXI_GEN_RRESP   ( s_axi_rresp             ), // output wire [1 : 0] S0_AXI_GEN_RRESP
                .S0_AXI_GEN_RLAST   ( s_axi_rlast             ), // output wire S0_AXI_GEN_RLAST
                .S0_AXI_GEN_RVALID  ( s_axi_rvalid            ), // output wire S0_AXI_GEN_RVALID
                .S0_AXI_GEN_RREADY  ( s_axi_rready            ), // input wire S0_AXI_GEN_RREADY
                .M0_AXI_AWID        ( to_clk_conv_axi_awid    ), // output wire [0 : 0] M0_AXI_AWID
                .M0_AXI_AWADDR      ( to_clk_conv_axi_awaddr  ), // output wire [31 : 0] M0_AXI_AWADDR
                .M0_AXI_AWLEN       ( to_clk_conv_axi_awlen   ), // output wire [7 : 0] M0_AXI_AWLEN
                .M0_AXI_AWSIZE      ( to_clk_conv_axi_awsize  ), // output wire [2 : 0] M0_AXI_AWSIZE
                .M0_AXI_AWBURST     ( to_clk_conv_axi_awburst ), // output wire [1 : 0] M0_AXI_AWBURST
                .M0_AXI_AWLOCK      ( to_clk_conv_axi_awlock  ), // output wire M0_AXI_AWLOCK
                .M0_AXI_AWCACHE     ( to_clk_conv_axi_awcache ), // output wire [3 : 0] M0_AXI_AWCACHE
                .M0_AXI_AWPROT      ( to_clk_conv_axi_awprot  ), // output wire [2 : 0] M0_AXI_AWPROT
                .M0_AXI_AWQOS       ( to_clk_conv_axi_awqos   ), // output wire [3 : 0] M0_AXI_AWQOS
                .M0_AXI_AWVALID     ( to_clk_conv_axi_awvalid ), // output wire M0_AXI_AWVALID
                .M0_AXI_AWREADY     ( to_clk_conv_axi_awready ), // input wire M0_AXI_AWREADY
                .M0_AXI_WDATA       ( to_clk_conv_axi_wdata   ), // output wire [511 : 0] M0_AXI_WDATA
                .M0_AXI_WSTRB       ( to_clk_conv_axi_wstrb   ), // output wire [3 : 0] M0_AXI_WSTRB
                .M0_AXI_WLAST       ( to_clk_conv_axi_wlast   ), // output wire M0_AXI_WLAST
                .M0_AXI_WVALID      ( to_clk_conv_axi_wvalid  ), // output wire M0_AXI_WVALID
                .M0_AXI_WREADY      ( to_clk_conv_axi_wready  ), // input wire M0_AXI_WREADY
                .M0_AXI_BRESP       ( to_clk_conv_axi_bresp   ), // input wire [1 : 0] M0_AXI_BRESP
                .M0_AXI_BID         ( to_clk_conv_axi_bid     ), // input wire [0 : 0] M0_AXI_BID
                .M0_AXI_BVALID      ( to_clk_conv_axi_bvalid  ), // input wire M0_AXI_BVALID
                .M0_AXI_BREADY      ( to_clk_conv_axi_bready  ), // output wire M0_AXI_BREADY
                .M0_AXI_ARID        ( to_clk_conv_axi_arid    ), // output wire [0 : 0] M0_AXI_ARID
                .M0_AXI_ARADDR      ( to_clk_conv_axi_araddr  ), // output wire [31 : 0] M0_AXI_ARADDR
                .M0_AXI_ARLEN       ( to_clk_conv_axi_arlen   ), // output wire [7 : 0] M0_AXI_ARLEN
                .M0_AXI_ARSIZE      ( to_clk_conv_axi_arsize  ), // output wire [2 : 0] M0_AXI_ARSIZE
                .M0_AXI_ARBURST     ( to_clk_conv_axi_arburst ), // output wire [1 : 0] M0_AXI_ARBURST
                .M0_AXI_ARLOCK      ( to_clk_conv_axi_arlock  ), // output wire M0_AXI_ARLOCK
                .M0_AXI_ARCACHE     ( to_clk_conv_axi_arcache ), // output wire [3 : 0] M0_AXI_ARCACHE
                .M0_AXI_ARPROT      ( to_clk_conv_axi_arprot  ), // output wire [2 : 0] M0_AXI_ARPROT
                .M0_AXI_ARQOS       ( to_clk_conv_axi_arqos   ), // output wire [3 : 0] M0_AXI_ARQOS
                .M0_AXI_ARVALID     ( to_clk_conv_axi_arvalid ), // output wire M0_AXI_ARVALID
                .M0_AXI_ARREADY     ( to_clk_conv_axi_arready ), // input wire M0_AXI_ARREADY
                .M0_AXI_RID         ( to_clk_conv_axi_rid     ), // input wire [0 : 0] M0_AXI_RID
                .M0_AXI_RDATA       ( to_clk_conv_axi_rdata   ), // input wire [511 : 0] M0_AXI_RDATA
                .M0_AXI_RRESP       ( to_clk_conv_axi_rresp   ), // input wire [1 : 0] M0_AXI_RRESP
                .M0_AXI_RLAST       ( to_clk_conv_axi_rlast   ), // input wire M0_AXI_RLAST
                .M0_AXI_RVALID      ( to_clk_conv_axi_rvalid  ), // input wire M0_AXI_RVALID
                .M0_AXI_RREADY      ( to_clk_conv_axi_rready  )  // output wire M0_AXI_RREADY
                );

    end else begin : no_cache

        // Dwidth converter master ID signals assigned to 0
        // Since the AXI data width converter has a reordering depth of 1 it doesn't have ID in its master ports - for more details see the documentation
        // Thus, we assign 0 to all these signals that go to the clock converter
        assign to_clk_conv_axi_awid = '0;
        assign to_clk_conv_axi_arid = '0;

        // AXI dwith converter from XLEN bit (global AXI data width) to 512 bit (AXI user interface DDR data width)
            xlnx_axi_dwidth_to512_converter axi_dwidth_conv_u (
                .s_axi_aclk     ( clock_i      ),
                .s_axi_aresetn  ( reset_ni     ),

                // Slave
                .s_axi_awid     ( s_axi_awid     ),
                .s_axi_awaddr   ( s_axi_awaddr   ),
                .s_axi_awlen    ( s_axi_awlen    ),
                .s_axi_awsize   ( s_axi_awsize   ),
                .s_axi_awburst  ( s_axi_awburst  ),
                .s_axi_awvalid  ( s_axi_awvalid  ),
                .s_axi_awready  ( s_axi_awready  ),
                .s_axi_wdata    ( s_axi_wdata    ),
                .s_axi_wstrb    ( s_axi_wstrb    ),
                .s_axi_wlast    ( s_axi_wlast    ),
                .s_axi_wvalid   ( s_axi_wvalid   ),
                .s_axi_wready   ( s_axi_wready   ),
                .s_axi_bid      ( s_axi_bid      ),
                .s_axi_bresp    ( s_axi_bresp    ),
                .s_axi_bvalid   ( s_axi_bvalid   ),
                .s_axi_bready   ( s_axi_bready   ),
                .s_axi_arid     ( s_axi_arid     ),
                .s_axi_araddr   ( s_axi_araddr   ),
                .s_axi_arlen    ( s_axi_arlen    ),
                .s_axi_arsize   ( s_axi_arsize   ),
                .s_axi_arburst  ( s_axi_arburst  ),
                .s_axi_arvalid  ( s_axi_arvalid  ),
                .s_axi_arready  ( s_axi_arready  ),
                .s_axi_rid      ( s_axi_rid      ),
                .s_axi_rdata    ( s_axi_rdata    ),
                .s_axi_rresp    ( s_axi_rresp    ),
                .s_axi_rlast    ( s_axi_rlast    ),
                .s_axi_rvalid   ( s_axi_rvalid   ),
                .s_axi_rready   ( s_axi_rready   ),
                .s_axi_awlock   ( s_axi_awlock   ),
                .s_axi_awcache  ( s_axi_awcache  ),
                .s_axi_awprot   ( s_axi_awprot   ),
                .s_axi_awqos    ( s_axi_awqos    ),
                .s_axi_awregion ( s_axi_awregion ),
                .s_axi_arlock   ( s_axi_arlock   ),
                .s_axi_arcache  ( s_axi_arcache  ),
                .s_axi_arprot   ( s_axi_arprot   ),
                .s_axi_arqos    ( s_axi_arqos    ),
                .s_axi_arregion ( s_axi_arregion ),

                // Master to Clock Converter
                //.m_axi_awid     ( dwidth_conv_to_cache_axi_awid    ),
                .m_axi_awaddr   ( to_clk_conv_axi_awaddr  ),
                .m_axi_awlen    ( to_clk_conv_axi_awlen   ),
                .m_axi_awsize   ( to_clk_conv_axi_awsize  ),
                .m_axi_awburst  ( to_clk_conv_axi_awburst ),
                .m_axi_awlock   ( to_clk_conv_axi_awlock  ),
                .m_axi_awcache  ( to_clk_conv_axi_awcache ),
                .m_axi_awprot   ( to_clk_conv_axi_awprot  ),
                .m_axi_awqos    ( to_clk_conv_axi_awqos   ),
                .m_axi_awvalid  ( to_clk_conv_axi_awvalid ),
                .m_axi_awready  ( to_clk_conv_axi_awready ),
                .m_axi_wdata    ( to_clk_conv_axi_wdata   ),
                .m_axi_wstrb    ( to_clk_conv_axi_wstrb   ),
                .m_axi_wlast    ( to_clk_conv_axi_wlast   ),
                .m_axi_wvalid   ( to_clk_conv_axi_wvalid  ),
                .m_axi_wready   ( to_clk_conv_axi_wready  ),
                //.m_axi_bid      ( dwidth_conv_to_cache_axi_bid     ),
                .m_axi_bresp    ( to_clk_conv_axi_bresp   ),
                .m_axi_bvalid   ( to_clk_conv_axi_bvalid  ),
                .m_axi_bready   ( to_clk_conv_axi_bready  ),
                //.m_axi_arid     ( dwidth_conv_to_cache_axi_arid    ),
                .m_axi_araddr   ( to_clk_conv_axi_araddr  ),
                .m_axi_arlen    ( to_clk_conv_axi_arlen   ),
                .m_axi_arsize   ( to_clk_conv_axi_arsize  ),
                .m_axi_arburst  ( to_clk_conv_axi_arburst ),
                .m_axi_arlock   ( to_clk_conv_axi_arlock  ),
                .m_axi_arcache  ( to_clk_conv_axi_arcache ),
                .m_axi_arprot   ( to_clk_conv_axi_arprot  ),
                .m_axi_arqos    ( to_clk_conv_axi_arqos   ),
                .m_axi_arvalid  ( to_clk_conv_axi_arvalid ),
                .m_axi_arready  ( to_clk_conv_axi_arready ),
                //.m_axi_rid      ( dwidth_conv_to_cache_axi_rid     ),
                .m_axi_rdata    ( to_clk_conv_axi_rdata   ),
                .m_axi_rresp    ( to_clk_conv_axi_rresp   ),
                .m_axi_rlast    ( to_clk_conv_axi_rlast   ),
                .m_axi_rvalid   ( to_clk_conv_axi_rvalid  ),
                .m_axi_rready   ( to_clk_conv_axi_rready  )
            );
        end
    endgenerate

    // AXI Clock converter from 250 MHz (xdma global design clk) to 300 MHz (AXI user interface DDR clk) - the data width is XLEN
    axi_clock_converter_wrapper # (
        .LOCAL_DATA_WIDTH   ( DDR4_CHANNEL_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH   ( LOCAL_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH     ( LOCAL_ID_WIDTH   )
    ) axi_clk_conv_u (

        .s_axi_aclk     ( clock_i        ),
        .s_axi_aresetn  ( reset_ni       ),

        .m_axi_aclk     ( ddr_clk        ),
        .m_axi_aresetn  ( ~ddr_rst       ),
        // Slave from Cache or Dwidth Converter
        .s_axi_awid     ( to_clk_conv_axi_awid     ),
        .s_axi_awaddr   ( to_clk_conv_axi_awaddr   ),
        .s_axi_awlen    ( to_clk_conv_axi_awlen    ),
        .s_axi_awsize   ( to_clk_conv_axi_awsize   ),
        .s_axi_awburst  ( to_clk_conv_axi_awburst  ),
        .s_axi_awlock   ( to_clk_conv_axi_awlock   ),
        .s_axi_awcache  ( to_clk_conv_axi_awcache  ),
        .s_axi_awprot   ( to_clk_conv_axi_awprot   ),
        .s_axi_awqos    ( to_clk_conv_axi_awqos    ),
        .s_axi_awvalid  ( to_clk_conv_axi_awvalid  ),
        .s_axi_awready  ( to_clk_conv_axi_awready  ),
        .s_axi_awregion ( to_clk_conv_axi_awregion ),
        .s_axi_wdata    ( to_clk_conv_axi_wdata    ),
        .s_axi_wstrb    ( to_clk_conv_axi_wstrb    ),
        .s_axi_wlast    ( to_clk_conv_axi_wlast    ),
        .s_axi_wvalid   ( to_clk_conv_axi_wvalid   ),
        .s_axi_wready   ( to_clk_conv_axi_wready   ),
        .s_axi_bid      ( to_clk_conv_axi_bid      ),
        .s_axi_bresp    ( to_clk_conv_axi_bresp    ),
        .s_axi_bvalid   ( to_clk_conv_axi_bvalid   ),
        .s_axi_bready   ( to_clk_conv_axi_bready   ),
        .s_axi_arid     ( to_clk_conv_axi_arid     ),
        .s_axi_araddr   ( to_clk_conv_axi_araddr   ),
        .s_axi_arlen    ( to_clk_conv_axi_arlen    ),
        .s_axi_arsize   ( to_clk_conv_axi_arsize   ),
        .s_axi_arburst  ( to_clk_conv_axi_arburst  ),
        .s_axi_arlock   ( to_clk_conv_axi_arlock   ),
        .s_axi_arregion ( to_clk_conv_axi_arregion ),
        .s_axi_arcache  ( to_clk_conv_axi_arcache  ),
        .s_axi_arprot   ( to_clk_conv_axi_arprot   ),
        .s_axi_arqos    ( to_clk_conv_axi_arqos    ),
        .s_axi_arvalid  ( to_clk_conv_axi_arvalid  ),
        .s_axi_arready  ( to_clk_conv_axi_arready  ),
        .s_axi_rid      ( to_clk_conv_axi_rid      ),
        .s_axi_rdata    ( to_clk_conv_axi_rdata    ),
        .s_axi_rresp    ( to_clk_conv_axi_rresp    ),
        .s_axi_rlast    ( to_clk_conv_axi_rlast    ),
        .s_axi_rvalid   ( to_clk_conv_axi_rvalid   ),
        .s_axi_rready   ( to_clk_conv_axi_rready   ),
        // Master to DDR
        .m_axi_awid     ( clk_conv_to_ddr4_axi_awid      ),
        .m_axi_awaddr   ( clk_conv_to_ddr4_axi_awaddr    ),
        .m_axi_awlen    ( clk_conv_to_ddr4_axi_awlen     ),
        .m_axi_awsize   ( clk_conv_to_ddr4_axi_awsize    ),
        .m_axi_awburst  ( clk_conv_to_ddr4_axi_awburst   ),
        .m_axi_awlock   ( clk_conv_to_ddr4_axi_awlock    ),
        .m_axi_awcache  ( clk_conv_to_ddr4_axi_awcache   ),
        .m_axi_awprot   ( clk_conv_to_ddr4_axi_awprot    ),
        .m_axi_awregion ( clk_conv_to_ddr4_axi_awregion  ),
        .m_axi_awqos    ( clk_conv_to_ddr4_axi_awqos     ),
        .m_axi_awvalid  ( clk_conv_to_ddr4_axi_awvalid   ),
        .m_axi_awready  ( clk_conv_to_ddr4_axi_awready   ),
        .m_axi_wdata    ( clk_conv_to_ddr4_axi_wdata     ),
        .m_axi_wstrb    ( clk_conv_to_ddr4_axi_wstrb     ),
        .m_axi_wlast    ( clk_conv_to_ddr4_axi_wlast     ),
        .m_axi_wvalid   ( clk_conv_to_ddr4_axi_wvalid    ),
        .m_axi_wready   ( clk_conv_to_ddr4_axi_wready    ),
        .m_axi_bid      ( clk_conv_to_ddr4_axi_bid       ),
        .m_axi_bresp    ( clk_conv_to_ddr4_axi_bresp     ),
        .m_axi_bvalid   ( clk_conv_to_ddr4_axi_bvalid    ),
        .m_axi_bready   ( clk_conv_to_ddr4_axi_bready    ),
        .m_axi_arid     ( clk_conv_to_ddr4_axi_arid      ),
        .m_axi_araddr   ( clk_conv_to_ddr4_axi_araddr    ),
        .m_axi_arlen    ( clk_conv_to_ddr4_axi_arlen     ),
        .m_axi_arsize   ( clk_conv_to_ddr4_axi_arsize    ),
        .m_axi_arburst  ( clk_conv_to_ddr4_axi_arburst   ),
        .m_axi_arlock   ( clk_conv_to_ddr4_axi_arlock    ),
        .m_axi_arcache  ( clk_conv_to_ddr4_axi_arcache   ),
        .m_axi_arprot   ( clk_conv_to_ddr4_axi_arprot    ),
        .m_axi_arregion ( clk_conv_to_ddr4_axi_arregion  ),
        .m_axi_arqos    ( clk_conv_to_ddr4_axi_arqos     ),
        .m_axi_arvalid  ( clk_conv_to_ddr4_axi_arvalid   ),
        .m_axi_arready  ( clk_conv_to_ddr4_axi_arready   ),
        .m_axi_rid      ( clk_conv_to_ddr4_axi_rid       ),
        .m_axi_rdata    ( clk_conv_to_ddr4_axi_rdata     ),
        .m_axi_rresp    ( clk_conv_to_ddr4_axi_rresp     ),
        .m_axi_rlast    ( clk_conv_to_ddr4_axi_rlast     ),
        .m_axi_rvalid   ( clk_conv_to_ddr4_axi_rvalid    ),
        .m_axi_rready   ( clk_conv_to_ddr4_axi_rready    )

    );


    // Map DDR4 address signals
    // Zero extend them if the address width is 32, otherwise clip them down.
    assign ddr4_axi_awaddr = (LOCAL_ADDR_WIDTH == 32) ? { 2'b00, clk_conv_to_ddr4_axi_awaddr } : clk_conv_to_ddr4_axi_awaddr[DDR4_CHANNEL_ADDRESS_WIDTH-1:0];
    assign ddr4_axi_araddr = (LOCAL_ADDR_WIDTH == 32) ? { 2'b00, clk_conv_to_ddr4_axi_araddr } : clk_conv_to_ddr4_axi_araddr[DDR4_CHANNEL_ADDRESS_WIDTH-1:0];

    xlnx_ddr4 ddr4_u (
        .c0_sys_clk_n                ( clk_300mhz_0_n_i ),
        .c0_sys_clk_p                ( clk_300mhz_0_p_i ),

        .sys_rst                     ( ddr4_reset       ),

        // Output - Calibration complete, the memory controller waits for this
        .c0_init_calib_complete      ( /* empty */      ),
        // Output - Interrupt about ECC
        .c0_ddr4_interrupt           ( /* empty */      ),
        // Output - these two debug ports must be open, in the implementation phase Vivado connects these two properly
        .dbg_clk                     ( /* empty */      ),
        .dbg_bus                     ( /* empty */      ),

        // DDR4 interface - to the physical memory
        .c0_ddr4_adr                 ( cx_ddr4_adr      ),
        .c0_ddr4_ba                  ( cx_ddr4_ba       ),
        .c0_ddr4_cke                 ( cx_ddr4_cke      ),
        .c0_ddr4_cs_n                ( cx_ddr4_cs_n     ),
        .c0_ddr4_dq                  ( cx_ddr4_dq       ),
        .c0_ddr4_dqs_t               ( cx_ddr4_dqs_t    ),
        .c0_ddr4_dqs_c               ( cx_ddr4_dqs_c    ),
        .c0_ddr4_odt                 ( cx_ddr4_odt      ),
        .c0_ddr4_parity              ( cx_ddr4_par      ),
        .c0_ddr4_bg                  ( cx_ddr4_bg       ),
        .c0_ddr4_reset_n             ( cx_ddr4_reset_n  ),
        .c0_ddr4_act_n               ( cx_ddr4_act_n    ),
        .c0_ddr4_ck_t                ( cx_ddr4_ck_t     ),
        .c0_ddr4_ck_c                ( cx_ddr4_ck_c     ),

        .c0_ddr4_ui_clk              ( ddr_clk          ),
        .c0_ddr4_ui_clk_sync_rst     ( ddr_rst          ),

        .c0_ddr4_aresetn             ( ~ddr_rst         ),

        // AXILITE interface - for status and control
        .c0_ddr4_s_axi_ctrl_awvalid  ( s_ctrl_axilite_awvalid ),
        .c0_ddr4_s_axi_ctrl_awready  ( s_ctrl_axilite_awready ),
        .c0_ddr4_s_axi_ctrl_awaddr   ( s_ctrl_axilite_awaddr  ),
        .c0_ddr4_s_axi_ctrl_wvalid   ( s_ctrl_axilite_wvalid  ),
        .c0_ddr4_s_axi_ctrl_wready   ( s_ctrl_axilite_wready  ),
        .c0_ddr4_s_axi_ctrl_wdata    ( s_ctrl_axilite_wdata   ),
        .c0_ddr4_s_axi_ctrl_bvalid   ( s_ctrl_axilite_bvalid  ),
        .c0_ddr4_s_axi_ctrl_bready   ( s_ctrl_axilite_bready  ),
        .c0_ddr4_s_axi_ctrl_bresp    ( s_ctrl_axilite_bresp   ),
        .c0_ddr4_s_axi_ctrl_arvalid  ( s_ctrl_axilite_arvalid ),
        .c0_ddr4_s_axi_ctrl_arready  ( s_ctrl_axilite_arready ),
        .c0_ddr4_s_axi_ctrl_araddr   ( s_ctrl_axilite_araddr  ),
        .c0_ddr4_s_axi_ctrl_rvalid   ( s_ctrl_axilite_rvalid  ),
        .c0_ddr4_s_axi_ctrl_rready   ( s_ctrl_axilite_rready  ),
        .c0_ddr4_s_axi_ctrl_rdata    ( s_ctrl_axilite_rdata   ),
        .c0_ddr4_s_axi_ctrl_rresp    ( s_ctrl_axilite_rresp   ),


        // AXI4 interface
        .c0_ddr4_s_axi_awid          ( clk_conv_to_ddr4_axi_awid    ),
        .c0_ddr4_s_axi_awaddr        ( ddr4_axi_awaddr              ),
        .c0_ddr4_s_axi_awlen         ( clk_conv_to_ddr4_axi_awlen   ),
        .c0_ddr4_s_axi_awsize        ( clk_conv_to_ddr4_axi_awsize  ),
        .c0_ddr4_s_axi_awburst       ( clk_conv_to_ddr4_axi_awburst ),
        .c0_ddr4_s_axi_awlock        ( clk_conv_to_ddr4_axi_awlock  ),
        .c0_ddr4_s_axi_awcache       ( clk_conv_to_ddr4_axi_awcache ),
        .c0_ddr4_s_axi_awprot        ( clk_conv_to_ddr4_axi_awprot  ),
        .c0_ddr4_s_axi_awqos         ( clk_conv_to_ddr4_axi_awqos   ),
        .c0_ddr4_s_axi_awvalid       ( clk_conv_to_ddr4_axi_awvalid ),
        .c0_ddr4_s_axi_awready       ( clk_conv_to_ddr4_axi_awready ),
        .c0_ddr4_s_axi_wdata         ( clk_conv_to_ddr4_axi_wdata   ),
        .c0_ddr4_s_axi_wstrb         ( clk_conv_to_ddr4_axi_wstrb   ),
        .c0_ddr4_s_axi_wlast         ( clk_conv_to_ddr4_axi_wlast   ),
        .c0_ddr4_s_axi_wvalid        ( clk_conv_to_ddr4_axi_wvalid  ),
        .c0_ddr4_s_axi_wready        ( clk_conv_to_ddr4_axi_wready  ),
        .c0_ddr4_s_axi_bready        ( clk_conv_to_ddr4_axi_bready  ),
        .c0_ddr4_s_axi_bid           ( clk_conv_to_ddr4_axi_bid     ),
        .c0_ddr4_s_axi_bresp         ( clk_conv_to_ddr4_axi_bresp   ),
        .c0_ddr4_s_axi_bvalid        ( clk_conv_to_ddr4_axi_bvalid  ),
        .c0_ddr4_s_axi_arid          ( clk_conv_to_ddr4_axi_arid    ),
        .c0_ddr4_s_axi_araddr        ( ddr4_axi_araddr              ),
        .c0_ddr4_s_axi_arlen         ( clk_conv_to_ddr4_axi_arlen   ),
        .c0_ddr4_s_axi_arsize        ( clk_conv_to_ddr4_axi_arsize  ),
        .c0_ddr4_s_axi_arburst       ( clk_conv_to_ddr4_axi_arburst ),
        .c0_ddr4_s_axi_arlock        ( clk_conv_to_ddr4_axi_arlock  ),
        .c0_ddr4_s_axi_arcache       ( clk_conv_to_ddr4_axi_arcache ),
        .c0_ddr4_s_axi_arprot        ( clk_conv_to_ddr4_axi_arprot  ),
        .c0_ddr4_s_axi_arqos         ( clk_conv_to_ddr4_axi_arqos   ),
        .c0_ddr4_s_axi_arvalid       ( clk_conv_to_ddr4_axi_arvalid ),
        .c0_ddr4_s_axi_arready       ( clk_conv_to_ddr4_axi_arready ),
        .c0_ddr4_s_axi_rready        ( clk_conv_to_ddr4_axi_rready  ),
        .c0_ddr4_s_axi_rlast         ( clk_conv_to_ddr4_axi_rlast   ),
        .c0_ddr4_s_axi_rvalid        ( clk_conv_to_ddr4_axi_rvalid  ),
        .c0_ddr4_s_axi_rresp         ( clk_conv_to_ddr4_axi_rresp   ),
        .c0_ddr4_s_axi_rid           ( clk_conv_to_ddr4_axi_rid     ),
        .c0_ddr4_s_axi_rdata         ( clk_conv_to_ddr4_axi_rdata   )
    );

endmodule
