// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
// Wrapper of the high-performance bus (HBUS) offering wide data interfaces, e.g. 512 bits. This bus offers several AXI interfaces:
//     - masters:
//        - to DDR channels (wide)
//        - to HBM channels (wide)
//        - m_MBUS: to MBUS (XLEN)
//    - slaves:
//        - s_MBUS: from MBUS (XLEN)
//        - s_acc: from accelerators (wide)
//    - Clocking
//        - each DDR or HBM channel is clocked in its own physical clock domain
//        - the core xbar is clocked on a high-speed clock from a physical DRAM domain, DDR channel 0 by default
//        - the core xbar clock/reset are exposed externally, e.g. for accelerators
//        - the MBUS interfaces (m_MBUS and s_MBUS) are already clock-bridged and data-width adapted
//
// Architecture:
//               ___________              _____________              ______________             ______________
// s_MBUS       |           | DATA: XLEN |             | DATA: 512  |              |           |              |_
// ------------>|   Clock   |----------->|   Dwidth    |----------->|              |---------->| DDR channels | |
//   Main clock | Converter |    HBUS    |  Converter  |            |     High     |---------->|    (MIG)     | |
//     domain   |___________|   domain   |_____________|            |  Performance |           |______________| |
//                                                                  |     XBAR     |             |______________|
// s_acc                                                            |              |            ______________
// ---------------------------------------------------------------->|              |           |              |_
// ---------------------------------------------------------------->|              |---------->| HBM channels | |
//                                   HBUS clock                     |              |---------->|    (TBD)     | |
//                                    domain                        |              |           |______________| |
//                                                                  |              |              |_____________|
//                                                                  |              |
//                                                                  |              |            _____________              ___________
//                                                                  |              | DATA: 512 |             | DATA: XLEN |           |
//                                                                  |              |---------->|   Dwidth    |----------->|   Clock   |-------> m_MBUS
//                                                                  |              |           |  Converter  |    HBUS    | Converter |  Main
//                                                                  |______________|           |_____________|   domain   |___________| domain
//
//

// Import packages
import uninasoc_pkg::*;

// Import headers
`include "uninasoc_axi.svh"
`include "uninasoc_ddr4.svh"

module highperformance_bus #(
    // HBUS AXI parameters
    parameter int unsigned    HBUS_DATA_WIDTH     = 512, // In bits
    parameter int unsigned    HBUS_ADDR_WIDTH     = 34,  // In bits
    parameter int unsigned    HBUS_ID_WIDTH       = 4,   // In bits
    // MBUS AXI parameters
    parameter int unsigned    MBUS_DATA_WIDTH     = 32,  // In bits, XLEN
    parameter int unsigned    MBUS_ADDR_WIDTH     = 32,  // In bits, PHYSICAL_ADDR_WIDTH
    parameter int unsigned    MBUS_ID_WIDTH       = 4,   // In bits
    // Lengths of port arrays
    parameter int unsigned    NUM_ACC_MASTERS     = 1,   // Number of accelerator masters to HBUS (TBD)
    parameter int unsigned    NUM_DDR_CHANNELS    = 1,   // Number of DDR channels under HBUS (TBD)
    parameter int unsigned    NUM_HBM_CHANNELS    = 0    // Number of HBM channels under HBUS (TBD)
)(

    // MBUS clock and reset
    input logic main_clock_i,
    input logic main_reset_ni,

    // AXI4 Slave interface from MBUS
    `DEFINE_AXI_SLAVE_PORTS(s_MBUS, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),
    // AXI4 Master interface to MBUS
    `DEFINE_AXI_MASTER_PORTS(m_MBUS, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),

    // TODO: expose an array of NUM_ACC_MASTERS interfaces
    // AXI4 Slave interface from accelerators
    `DEFINE_AXI_SLAVE_PORTS(s_acc, HBUS_DATA_WIDTH, HBUS_ADDR_WIDTH, HBUS_ID_WIDTH),

    // TODO: expose an array of NUM_DDR_CHANNELS pins and interfaces
    // DDR4 CH<x> clock and reset
    input logic clk_300mhz_x_p_i,
    input logic clk_300mhz_x_n_i,
    // DDR4 channel output clock and reset
    output logic clk_300MHz_o,
    output logic rstn_300MHz_o,
    // DDR channel
    `DEFINE_DDR4_PORTS(x),
    // AXI-lite CSR interface
    `DEFINE_AXILITE_SLAVE_PORTS(s_ctrl, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH)

    // TODO: expose an array of NUM_HBM_CHANNELS pins and interfaces
    // TBD
);

    // Ensure HBUS has clock domain
    `ifndef HBUS_HAS_CLOCK_DOMAIN
        $error("HBUS must be in have its own clock domain!");
    `endif

    // For simplicity
    initial begin : assert_properties
        assert( MBUS_ID_WIDTH == HBUS_ID_WIDTH )
            else $error("HBUS_ID_WIDTH (%d) must be the same as MBUS_ID_WIDTH (%d)", HBUS_ID_WIDTH, MBUS_ID_WIDTH);
    end : assert_properties

    /////////////////
    // Assignments //
    /////////////////
    assign clk_300MHz_o  = ddr_clk;
    assign rstn_300MHz_o = ~ddr_rst;

    /////////////////////////////////////////
    // Buses declaration and concatenation //
    /////////////////////////////////////////
    `include "hbus_buses.svinc"
    // MBUS_DATA_WIDTH
    `DECLARE_AXI_BUS(s_MBUS_clock_conv_to_dwidth_conv, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH)
    `DECLARE_AXI_BUS(m_MBUS_dwidth_conv_to_clock_conv, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH)
    // HBUS_DATA_WIDTH, and MBUS address and id width
    `DECLARE_AXI_BUS(dwidth_conv_to_HBUS             , HBUS_DATA_WIDTH, HBUS_ADDR_WIDTH, HBUS_ID_WIDTH)
    `DECLARE_AXI_BUS(dwidth_conv_from_HBUS           , HBUS_DATA_WIDTH, HBUS_ADDR_WIDTH, HBUS_ID_WIDTH)

    // HBUS <-> MBUS interconnect
    // - s_MBUS (slave from MBUS)
    // (s_MBUS) -> xlnx_axi_clock_converter_s_MBUS_u -> (s_MBUS_clock_conv_to_dwidth_conv) -> axi_dwidth_conv_s_MBUS_u -> (dwidth_conv_to_HBUS) -> ASSIGN_AXI_BUS -> (MBUS_to_HBUS)
    // - m_MBUS (master to MBUS)
    // (HBUS_to_MBUS) -> ASSIGN_AXI_BUS -> (dwidth_conv_from_HBUS) -> axi_dwidth_conv_m_MBUS_u -> (m_MBUS_dwidth_conv_to_clock_conv) -> xlnx_axi_clock_converter_m_MBUS_u -> (m_MBUS)

    ////////////////////
    // AXI Converters //
    ////////////////////

    logic HBUS_clk ;
    logic HBUS_rstn;
    assign HBUS_clk  = ddr_clk;
    assign HBUS_rstn = ~ddr_rst;

    // Clock converter
    // s_MBUS -> s_MBUS_clock_conv_to_dwidth_conv
    axi_clock_converter_wrapper # (
        .LOCAL_DATA_WIDTH   ( MBUS_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH   ( MBUS_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH     ( MBUS_ID_WIDTH   )
    ) xlnx_axi_clock_converter_s_MBUS_u (
        // Slave from MBUS
        .s_axi_aclk     ( main_clock_i   ),
        .s_axi_aresetn  ( main_reset_ni  ),
        .s_axi_awid     ( s_MBUS_axi_awid     ),
        .s_axi_awaddr   ( s_MBUS_axi_awaddr   ),
        .s_axi_awlen    ( s_MBUS_axi_awlen    ),
        .s_axi_awsize   ( s_MBUS_axi_awsize   ),
        .s_axi_awburst  ( s_MBUS_axi_awburst  ),
        .s_axi_awlock   ( s_MBUS_axi_awlock   ),
        .s_axi_awcache  ( s_MBUS_axi_awcache  ),
        .s_axi_awprot   ( s_MBUS_axi_awprot   ),
        .s_axi_awqos    ( s_MBUS_axi_awqos    ),
        .s_axi_awvalid  ( s_MBUS_axi_awvalid  ),
        .s_axi_awready  ( s_MBUS_axi_awready  ),
        .s_axi_awregion ( s_MBUS_axi_awregion ),
        .s_axi_wdata    ( s_MBUS_axi_wdata    ),
        .s_axi_wstrb    ( s_MBUS_axi_wstrb    ),
        .s_axi_wlast    ( s_MBUS_axi_wlast    ),
        .s_axi_wvalid   ( s_MBUS_axi_wvalid   ),
        .s_axi_wready   ( s_MBUS_axi_wready   ),
        .s_axi_bid      ( s_MBUS_axi_bid      ),
        .s_axi_bresp    ( s_MBUS_axi_bresp    ),
        .s_axi_bvalid   ( s_MBUS_axi_bvalid   ),
        .s_axi_bready   ( s_MBUS_axi_bready   ),
        .s_axi_arid     ( s_MBUS_axi_arid     ),
        .s_axi_araddr   ( s_MBUS_axi_araddr   ),
        .s_axi_arlen    ( s_MBUS_axi_arlen    ),
        .s_axi_arsize   ( s_MBUS_axi_arsize   ),
        .s_axi_arburst  ( s_MBUS_axi_arburst  ),
        .s_axi_arlock   ( s_MBUS_axi_arlock   ),
        .s_axi_arregion ( s_MBUS_axi_arregion ),
        .s_axi_arcache  ( s_MBUS_axi_arcache  ),
        .s_axi_arprot   ( s_MBUS_axi_arprot   ),
        .s_axi_arqos    ( s_MBUS_axi_arqos    ),
        .s_axi_arvalid  ( s_MBUS_axi_arvalid  ),
        .s_axi_arready  ( s_MBUS_axi_arready  ),
        .s_axi_rid      ( s_MBUS_axi_rid      ),
        .s_axi_rdata    ( s_MBUS_axi_rdata    ),
        .s_axi_rresp    ( s_MBUS_axi_rresp    ),
        .s_axi_rlast    ( s_MBUS_axi_rlast    ),
        .s_axi_rvalid   ( s_MBUS_axi_rvalid   ),
        .s_axi_rready   ( s_MBUS_axi_rready   ),
        // Master to HBUS
        .m_axi_aclk     ( HBUS_clk        ),
        .m_axi_aresetn  ( HBUS_rstn       ),
        .m_axi_awid     ( s_MBUS_clock_conv_to_dwidth_conv_axi_awid     ),
        .m_axi_awaddr   ( s_MBUS_clock_conv_to_dwidth_conv_axi_awaddr   ),
        .m_axi_awlen    ( s_MBUS_clock_conv_to_dwidth_conv_axi_awlen    ),
        .m_axi_awsize   ( s_MBUS_clock_conv_to_dwidth_conv_axi_awsize   ),
        .m_axi_awburst  ( s_MBUS_clock_conv_to_dwidth_conv_axi_awburst  ),
        .m_axi_awlock   ( s_MBUS_clock_conv_to_dwidth_conv_axi_awlock   ),
        .m_axi_awcache  ( s_MBUS_clock_conv_to_dwidth_conv_axi_awcache  ),
        .m_axi_awprot   ( s_MBUS_clock_conv_to_dwidth_conv_axi_awprot   ),
        .m_axi_awregion ( s_MBUS_clock_conv_to_dwidth_conv_axi_awregion ), // Open
        .m_axi_awqos    ( s_MBUS_clock_conv_to_dwidth_conv_axi_awqos    ), // Open
        .m_axi_awvalid  ( s_MBUS_clock_conv_to_dwidth_conv_axi_awvalid  ),
        .m_axi_awready  ( s_MBUS_clock_conv_to_dwidth_conv_axi_awready  ),
        .m_axi_wdata    ( s_MBUS_clock_conv_to_dwidth_conv_axi_wdata    ),
        .m_axi_wstrb    ( s_MBUS_clock_conv_to_dwidth_conv_axi_wstrb    ),
        .m_axi_wlast    ( s_MBUS_clock_conv_to_dwidth_conv_axi_wlast    ),
        .m_axi_wvalid   ( s_MBUS_clock_conv_to_dwidth_conv_axi_wvalid   ),
        .m_axi_wready   ( s_MBUS_clock_conv_to_dwidth_conv_axi_wready   ),
        .m_axi_bid      ( s_MBUS_clock_conv_to_dwidth_conv_axi_bid      ),
        .m_axi_bresp    ( s_MBUS_clock_conv_to_dwidth_conv_axi_bresp    ),
        .m_axi_bvalid   ( s_MBUS_clock_conv_to_dwidth_conv_axi_bvalid   ),
        .m_axi_bready   ( s_MBUS_clock_conv_to_dwidth_conv_axi_bready   ),
        .m_axi_arid     ( s_MBUS_clock_conv_to_dwidth_conv_axi_arid     ),
        .m_axi_araddr   ( s_MBUS_clock_conv_to_dwidth_conv_axi_araddr   ),
        .m_axi_arlen    ( s_MBUS_clock_conv_to_dwidth_conv_axi_arlen    ),
        .m_axi_arsize   ( s_MBUS_clock_conv_to_dwidth_conv_axi_arsize   ),
        .m_axi_arburst  ( s_MBUS_clock_conv_to_dwidth_conv_axi_arburst  ),
        .m_axi_arlock   ( s_MBUS_clock_conv_to_dwidth_conv_axi_arlock   ),
        .m_axi_arcache  ( s_MBUS_clock_conv_to_dwidth_conv_axi_arcache  ),
        .m_axi_arprot   ( s_MBUS_clock_conv_to_dwidth_conv_axi_arprot   ),
        .m_axi_arregion ( s_MBUS_clock_conv_to_dwidth_conv_axi_arregion ), // Open
        .m_axi_arqos    ( s_MBUS_clock_conv_to_dwidth_conv_axi_arqos    ), // Open
        .m_axi_arvalid  ( s_MBUS_clock_conv_to_dwidth_conv_axi_arvalid  ),
        .m_axi_arready  ( s_MBUS_clock_conv_to_dwidth_conv_axi_arready  ),
        .m_axi_rid      ( s_MBUS_clock_conv_to_dwidth_conv_axi_rid      ),
        .m_axi_rdata    ( s_MBUS_clock_conv_to_dwidth_conv_axi_rdata    ),
        .m_axi_rresp    ( s_MBUS_clock_conv_to_dwidth_conv_axi_rresp    ),
        .m_axi_rlast    ( s_MBUS_clock_conv_to_dwidth_conv_axi_rlast    ),
        .m_axi_rvalid   ( s_MBUS_clock_conv_to_dwidth_conv_axi_rvalid   ),
        .m_axi_rready   ( s_MBUS_clock_conv_to_dwidth_conv_axi_rready   )
    );

    // AXI dwith converter from 32 bit (global AXI data width) to 512 bit (AXI user interface HBUS data width)
    // Tie-off undriven nets
    // s_MBUS_clock_conv_to_dwidth_conv -> dwidth_conv_to_HBUS
    xlnx_axi_dwidth_to512_converter axi_dwidth_conv_s_MBUS_u (
        .s_axi_aclk     ( HBUS_clk     ),
        .s_axi_aresetn  ( HBUS_rstn  ),
        // Slave from clock conv
        .s_axi_awid     ( s_MBUS_clock_conv_to_dwidth_conv_axi_awid    ),
        .s_axi_awaddr   ( s_MBUS_clock_conv_to_dwidth_conv_axi_awaddr  ),
        .s_axi_awlen    ( s_MBUS_clock_conv_to_dwidth_conv_axi_awlen   ),
        .s_axi_awsize   ( s_MBUS_clock_conv_to_dwidth_conv_axi_awsize  ),
        .s_axi_awburst  ( s_MBUS_clock_conv_to_dwidth_conv_axi_awburst ),
        .s_axi_awvalid  ( s_MBUS_clock_conv_to_dwidth_conv_axi_awvalid ),
        .s_axi_awready  ( s_MBUS_clock_conv_to_dwidth_conv_axi_awready ),
        .s_axi_wdata    ( s_MBUS_clock_conv_to_dwidth_conv_axi_wdata   ),
        .s_axi_wstrb    ( s_MBUS_clock_conv_to_dwidth_conv_axi_wstrb   ),
        .s_axi_wlast    ( s_MBUS_clock_conv_to_dwidth_conv_axi_wlast   ),
        .s_axi_wvalid   ( s_MBUS_clock_conv_to_dwidth_conv_axi_wvalid  ),
        .s_axi_wready   ( s_MBUS_clock_conv_to_dwidth_conv_axi_wready  ),
        .s_axi_bid      ( s_MBUS_clock_conv_to_dwidth_conv_axi_bid     ),
        .s_axi_bresp    ( s_MBUS_clock_conv_to_dwidth_conv_axi_bresp   ),
        .s_axi_bvalid   ( s_MBUS_clock_conv_to_dwidth_conv_axi_bvalid  ),
        .s_axi_bready   ( s_MBUS_clock_conv_to_dwidth_conv_axi_bready  ),
        .s_axi_arid     ( s_MBUS_clock_conv_to_dwidth_conv_axi_arid    ),
        .s_axi_araddr   ( s_MBUS_clock_conv_to_dwidth_conv_axi_araddr  ),
        .s_axi_arlen    ( s_MBUS_clock_conv_to_dwidth_conv_axi_arlen   ),
        .s_axi_arsize   ( s_MBUS_clock_conv_to_dwidth_conv_axi_arsize  ),
        .s_axi_arburst  ( s_MBUS_clock_conv_to_dwidth_conv_axi_arburst ),
        .s_axi_arvalid  ( s_MBUS_clock_conv_to_dwidth_conv_axi_arvalid ),
        .s_axi_arready  ( s_MBUS_clock_conv_to_dwidth_conv_axi_arready ),
        .s_axi_rid      ( s_MBUS_clock_conv_to_dwidth_conv_axi_rid     ),
        .s_axi_rdata    ( s_MBUS_clock_conv_to_dwidth_conv_axi_rdata   ),
        .s_axi_rresp    ( s_MBUS_clock_conv_to_dwidth_conv_axi_rresp   ),
        .s_axi_rlast    ( s_MBUS_clock_conv_to_dwidth_conv_axi_rlast   ),
        .s_axi_rvalid   ( s_MBUS_clock_conv_to_dwidth_conv_axi_rvalid  ),
        .s_axi_rready   ( s_MBUS_clock_conv_to_dwidth_conv_axi_rready  ),
        .s_axi_awlock   ( s_MBUS_clock_conv_to_dwidth_conv_axi_awlock  ),
        .s_axi_awcache  ( s_MBUS_clock_conv_to_dwidth_conv_axi_awcache ),
        .s_axi_awprot   ( s_MBUS_clock_conv_to_dwidth_conv_axi_awprot  ),
        .s_axi_awqos    ( s_MBUS_clock_conv_to_dwidth_conv_axi_awqos   ),
        .s_axi_awregion ( s_MBUS_clock_conv_to_dwidth_conv_axi_awregion),
        .s_axi_arlock   ( s_MBUS_clock_conv_to_dwidth_conv_axi_arlock  ),
        .s_axi_arcache  ( s_MBUS_clock_conv_to_dwidth_conv_axi_arcache ),
        .s_axi_arprot   ( s_MBUS_clock_conv_to_dwidth_conv_axi_arprot  ),
        .s_axi_arqos    ( s_MBUS_clock_conv_to_dwidth_conv_axi_arqos   ),
        .s_axi_arregion ( s_MBUS_clock_conv_to_dwidth_conv_axi_arregion),
        // Master to DDR
        // .m_axi_awid     ( dwidth_conv_to_HBUS_axi_awid    ),
        .m_axi_awaddr   ( dwidth_conv_to_HBUS_axi_awaddr  ),
        .m_axi_awlen    ( dwidth_conv_to_HBUS_axi_awlen   ),
        .m_axi_awsize   ( dwidth_conv_to_HBUS_axi_awsize  ),
        .m_axi_awburst  ( dwidth_conv_to_HBUS_axi_awburst ),
        .m_axi_awlock   ( dwidth_conv_to_HBUS_axi_awlock  ),
        .m_axi_awcache  ( dwidth_conv_to_HBUS_axi_awcache ),
        .m_axi_awprot   ( dwidth_conv_to_HBUS_axi_awprot  ),
        .m_axi_awqos    ( dwidth_conv_to_HBUS_axi_awqos   ),
        .m_axi_awvalid  ( dwidth_conv_to_HBUS_axi_awvalid ),
        .m_axi_awready  ( dwidth_conv_to_HBUS_axi_awready ),
        .m_axi_wdata    ( dwidth_conv_to_HBUS_axi_wdata   ),
        .m_axi_wstrb    ( dwidth_conv_to_HBUS_axi_wstrb   ),
        .m_axi_wlast    ( dwidth_conv_to_HBUS_axi_wlast   ),
        .m_axi_wvalid   ( dwidth_conv_to_HBUS_axi_wvalid  ),
        .m_axi_wready   ( dwidth_conv_to_HBUS_axi_wready  ),
        // .m_axi_bid      ( dwidth_conv_to_HBUS_axi_bid     ),
        .m_axi_bresp    ( dwidth_conv_to_HBUS_axi_bresp   ),
        .m_axi_bvalid   ( dwidth_conv_to_HBUS_axi_bvalid  ),
        .m_axi_bready   ( dwidth_conv_to_HBUS_axi_bready  ),
        // .m_axi_arid     ( dwidth_conv_to_HBUS_axi_arid    ),
        .m_axi_araddr   ( dwidth_conv_to_HBUS_axi_araddr  ),
        .m_axi_arlen    ( dwidth_conv_to_HBUS_axi_arlen   ),
        .m_axi_arsize   ( dwidth_conv_to_HBUS_axi_arsize  ),
        .m_axi_arburst  ( dwidth_conv_to_HBUS_axi_arburst ),
        .m_axi_arlock   ( dwidth_conv_to_HBUS_axi_arlock  ),
        .m_axi_arcache  ( dwidth_conv_to_HBUS_axi_arcache ),
        .m_axi_arprot   ( dwidth_conv_to_HBUS_axi_arprot  ),
        .m_axi_arqos    ( dwidth_conv_to_HBUS_axi_arqos   ),
        .m_axi_arvalid  ( dwidth_conv_to_HBUS_axi_arvalid ),
        .m_axi_arready  ( dwidth_conv_to_HBUS_axi_arready ),
        // .m_axi_rid      ( dwidth_conv_to_HBUS_axi_rid     ),
        .m_axi_rdata    ( dwidth_conv_to_HBUS_axi_rdata   ),
        .m_axi_rresp    ( dwidth_conv_to_HBUS_axi_rresp   ),
        .m_axi_rlast    ( dwidth_conv_to_HBUS_axi_rlast   ),
        .m_axi_rvalid   ( dwidth_conv_to_HBUS_axi_rvalid  ),
        .m_axi_rready   ( dwidth_conv_to_HBUS_axi_rready  ),
        // Unconnected nets
        .m_axi_awregion ( dwidth_conv_to_HBUS_axi_awregion ),
        .m_axi_arregion ( dwidth_conv_to_HBUS_axi_arregion )
    );

    // AXI dwith converter from 32 bit (global AXI data width) to 512 bit (AXI user interface HBUS data width)
    // dwidth_conv_from_HBUS -> m_MBUS_dwidth_conv_to_clock_conv
    xlnx_axi_dwidth_from512_converter axi_dwidth_conv_m_MBUS_u (
        // Clock and reset
        .s_axi_aclk     ( HBUS_clk   ),
        .s_axi_aresetn  ( HBUS_rstn  ),

        // Slave from clock conv
        .s_axi_awid     ( dwidth_conv_from_HBUS_axi_awid    ),
        .s_axi_awaddr   ( dwidth_conv_from_HBUS_axi_awaddr  ),
        .s_axi_awlen    ( dwidth_conv_from_HBUS_axi_awlen   ),
        .s_axi_awsize   ( dwidth_conv_from_HBUS_axi_awsize  ),
        .s_axi_awburst  ( dwidth_conv_from_HBUS_axi_awburst ),
        .s_axi_awvalid  ( dwidth_conv_from_HBUS_axi_awvalid ),
        .s_axi_awready  ( dwidth_conv_from_HBUS_axi_awready ),
        .s_axi_wdata    ( dwidth_conv_from_HBUS_axi_wdata   ),
        .s_axi_wstrb    ( dwidth_conv_from_HBUS_axi_wstrb   ),
        .s_axi_wlast    ( dwidth_conv_from_HBUS_axi_wlast   ),
        .s_axi_wvalid   ( dwidth_conv_from_HBUS_axi_wvalid  ),
        .s_axi_wready   ( dwidth_conv_from_HBUS_axi_wready  ),
        .s_axi_bid      ( dwidth_conv_from_HBUS_axi_bid     ),
        .s_axi_bresp    ( dwidth_conv_from_HBUS_axi_bresp   ),
        .s_axi_bvalid   ( dwidth_conv_from_HBUS_axi_bvalid  ),
        .s_axi_bready   ( dwidth_conv_from_HBUS_axi_bready  ),
        .s_axi_arid     ( dwidth_conv_from_HBUS_axi_arid    ),
        .s_axi_araddr   ( dwidth_conv_from_HBUS_axi_araddr  ),
        .s_axi_arlen    ( dwidth_conv_from_HBUS_axi_arlen   ),
        .s_axi_arsize   ( dwidth_conv_from_HBUS_axi_arsize  ),
        .s_axi_arburst  ( dwidth_conv_from_HBUS_axi_arburst ),
        .s_axi_arvalid  ( dwidth_conv_from_HBUS_axi_arvalid ),
        .s_axi_arready  ( dwidth_conv_from_HBUS_axi_arready ),
        .s_axi_rid      ( dwidth_conv_from_HBUS_axi_rid     ),
        .s_axi_rdata    ( dwidth_conv_from_HBUS_axi_rdata   ),
        .s_axi_rresp    ( dwidth_conv_from_HBUS_axi_rresp   ),
        .s_axi_rlast    ( dwidth_conv_from_HBUS_axi_rlast   ),
        .s_axi_rvalid   ( dwidth_conv_from_HBUS_axi_rvalid  ),
        .s_axi_rready   ( dwidth_conv_from_HBUS_axi_rready  ),
        .s_axi_awlock   ( dwidth_conv_from_HBUS_axi_awlock  ),
        .s_axi_awcache  ( dwidth_conv_from_HBUS_axi_awcache ),
        .s_axi_awprot   ( dwidth_conv_from_HBUS_axi_awprot  ),
        .s_axi_awqos    ( dwidth_conv_from_HBUS_axi_awqos   ),
        .s_axi_awregion ( dwidth_conv_from_HBUS_axi_awregion),
        .s_axi_arlock   ( dwidth_conv_from_HBUS_axi_arlock  ),
        .s_axi_arcache  ( dwidth_conv_from_HBUS_axi_arcache ), // Open
        .s_axi_arprot   ( dwidth_conv_from_HBUS_axi_arprot  ), // Open
        .s_axi_arqos    ( dwidth_conv_from_HBUS_axi_arqos   ), // Open
        .s_axi_arregion ( dwidth_conv_from_HBUS_axi_arregion), // Open
        // Master
        // .m_axi_awid     ( m_MBUS_dwidth_conv_to_clock_conv_axi_awid    ),
        .m_axi_awaddr   ( m_MBUS_dwidth_conv_to_clock_conv_axi_awaddr  ),
        .m_axi_awlen    ( m_MBUS_dwidth_conv_to_clock_conv_axi_awlen   ),
        .m_axi_awsize   ( m_MBUS_dwidth_conv_to_clock_conv_axi_awsize  ),
        .m_axi_awburst  ( m_MBUS_dwidth_conv_to_clock_conv_axi_awburst ),
        .m_axi_awlock   ( m_MBUS_dwidth_conv_to_clock_conv_axi_awlock  ),
        .m_axi_awcache  ( m_MBUS_dwidth_conv_to_clock_conv_axi_awcache ),
        .m_axi_awprot   ( m_MBUS_dwidth_conv_to_clock_conv_axi_awprot  ),
        .m_axi_awqos    ( m_MBUS_dwidth_conv_to_clock_conv_axi_awqos   ),
        .m_axi_awvalid  ( m_MBUS_dwidth_conv_to_clock_conv_axi_awvalid ),
        .m_axi_awready  ( m_MBUS_dwidth_conv_to_clock_conv_axi_awready ),
        .m_axi_wdata    ( m_MBUS_dwidth_conv_to_clock_conv_axi_wdata   ),
        .m_axi_wstrb    ( m_MBUS_dwidth_conv_to_clock_conv_axi_wstrb   ),
        .m_axi_wlast    ( m_MBUS_dwidth_conv_to_clock_conv_axi_wlast   ),
        .m_axi_wvalid   ( m_MBUS_dwidth_conv_to_clock_conv_axi_wvalid  ),
        .m_axi_wready   ( m_MBUS_dwidth_conv_to_clock_conv_axi_wready  ),
        // .m_axi_bid      ( m_MBUS_dwidth_conv_to_clock_conv_axi_bid     ),
        .m_axi_bresp    ( m_MBUS_dwidth_conv_to_clock_conv_axi_bresp   ),
        .m_axi_bvalid   ( m_MBUS_dwidth_conv_to_clock_conv_axi_bvalid  ),
        .m_axi_bready   ( m_MBUS_dwidth_conv_to_clock_conv_axi_bready  ),
        // .m_axi_arid     ( m_MBUS_dwidth_conv_to_clock_conv_axi_arid    ),
        .m_axi_araddr   ( m_MBUS_dwidth_conv_to_clock_conv_axi_araddr  ),
        .m_axi_arlen    ( m_MBUS_dwidth_conv_to_clock_conv_axi_arlen   ),
        .m_axi_arsize   ( m_MBUS_dwidth_conv_to_clock_conv_axi_arsize  ),
        .m_axi_arburst  ( m_MBUS_dwidth_conv_to_clock_conv_axi_arburst ),
        .m_axi_arlock   ( m_MBUS_dwidth_conv_to_clock_conv_axi_arlock  ),
        .m_axi_arcache  ( m_MBUS_dwidth_conv_to_clock_conv_axi_arcache ),
        .m_axi_arprot   ( m_MBUS_dwidth_conv_to_clock_conv_axi_arprot  ),
        .m_axi_arqos    ( m_MBUS_dwidth_conv_to_clock_conv_axi_arqos   ),
        .m_axi_arvalid  ( m_MBUS_dwidth_conv_to_clock_conv_axi_arvalid ),
        .m_axi_arready  ( m_MBUS_dwidth_conv_to_clock_conv_axi_arready ),
        // .m_axi_rid      ( m_MBUS_dwidth_conv_to_clock_conv_axi_rid     ),
        .m_axi_rdata    ( m_MBUS_dwidth_conv_to_clock_conv_axi_rdata   ),
        .m_axi_rresp    ( m_MBUS_dwidth_conv_to_clock_conv_axi_rresp   ),
        .m_axi_rlast    ( m_MBUS_dwidth_conv_to_clock_conv_axi_rlast   ),
        .m_axi_rvalid   ( m_MBUS_dwidth_conv_to_clock_conv_axi_rvalid  ),
        .m_axi_rready   ( m_MBUS_dwidth_conv_to_clock_conv_axi_rready  ),
        // Unconnected nets
        .m_axi_awregion ( m_MBUS_dwidth_conv_to_clock_conv_axi_awregion ),
        .m_axi_arregion ( m_MBUS_dwidth_conv_to_clock_conv_axi_arregion )
    );

    // Clock converter
    // s_MBUS_clock_conv_to_dwidth_conv -> m_MBUS
    axi_clock_converter_wrapper # (
        .LOCAL_DATA_WIDTH   ( MBUS_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH   ( MBUS_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH     ( MBUS_ID_WIDTH   )
    ) xlnx_axi_clock_converter_m_MBUS_u (
        // Slave from BUS
        .s_axi_aclk     ( HBUS_clk     ),
        .s_axi_aresetn  ( HBUS_rstn    ),
        .s_axi_awid     ( m_MBUS_dwidth_conv_to_clock_conv_axi_awid     ),
        .s_axi_awaddr   ( m_MBUS_dwidth_conv_to_clock_conv_axi_awaddr   ),
        .s_axi_awlen    ( m_MBUS_dwidth_conv_to_clock_conv_axi_awlen    ),
        .s_axi_awsize   ( m_MBUS_dwidth_conv_to_clock_conv_axi_awsize   ),
        .s_axi_awburst  ( m_MBUS_dwidth_conv_to_clock_conv_axi_awburst  ),
        .s_axi_awlock   ( m_MBUS_dwidth_conv_to_clock_conv_axi_awlock   ),
        .s_axi_awcache  ( m_MBUS_dwidth_conv_to_clock_conv_axi_awcache  ),
        .s_axi_awprot   ( m_MBUS_dwidth_conv_to_clock_conv_axi_awprot   ),
        .s_axi_awqos    ( m_MBUS_dwidth_conv_to_clock_conv_axi_awqos    ),
        .s_axi_awvalid  ( m_MBUS_dwidth_conv_to_clock_conv_axi_awvalid  ),
        .s_axi_awready  ( m_MBUS_dwidth_conv_to_clock_conv_axi_awready  ),
        .s_axi_awregion ( m_MBUS_dwidth_conv_to_clock_conv_axi_awregion ),
        .s_axi_wdata    ( m_MBUS_dwidth_conv_to_clock_conv_axi_wdata    ),
        .s_axi_wstrb    ( m_MBUS_dwidth_conv_to_clock_conv_axi_wstrb    ),
        .s_axi_wlast    ( m_MBUS_dwidth_conv_to_clock_conv_axi_wlast    ),
        .s_axi_wvalid   ( m_MBUS_dwidth_conv_to_clock_conv_axi_wvalid   ),
        .s_axi_wready   ( m_MBUS_dwidth_conv_to_clock_conv_axi_wready   ),
        .s_axi_bid      ( m_MBUS_dwidth_conv_to_clock_conv_axi_bid      ),
        .s_axi_bresp    ( m_MBUS_dwidth_conv_to_clock_conv_axi_bresp    ),
        .s_axi_bvalid   ( m_MBUS_dwidth_conv_to_clock_conv_axi_bvalid   ),
        .s_axi_bready   ( m_MBUS_dwidth_conv_to_clock_conv_axi_bready   ),
        .s_axi_arid     ( m_MBUS_dwidth_conv_to_clock_conv_axi_arid     ),
        .s_axi_araddr   ( m_MBUS_dwidth_conv_to_clock_conv_axi_araddr   ),
        .s_axi_arlen    ( m_MBUS_dwidth_conv_to_clock_conv_axi_arlen    ),
        .s_axi_arsize   ( m_MBUS_dwidth_conv_to_clock_conv_axi_arsize   ),
        .s_axi_arburst  ( m_MBUS_dwidth_conv_to_clock_conv_axi_arburst  ),
        .s_axi_arlock   ( m_MBUS_dwidth_conv_to_clock_conv_axi_arlock   ),
        .s_axi_arregion ( m_MBUS_dwidth_conv_to_clock_conv_axi_arregion ),
        .s_axi_arcache  ( m_MBUS_dwidth_conv_to_clock_conv_axi_arcache  ),
        .s_axi_arprot   ( m_MBUS_dwidth_conv_to_clock_conv_axi_arprot   ),
        .s_axi_arqos    ( m_MBUS_dwidth_conv_to_clock_conv_axi_arqos    ),
        .s_axi_arvalid  ( m_MBUS_dwidth_conv_to_clock_conv_axi_arvalid  ),
        .s_axi_arready  ( m_MBUS_dwidth_conv_to_clock_conv_axi_arready  ),
        .s_axi_rid      ( m_MBUS_dwidth_conv_to_clock_conv_axi_rid      ),
        .s_axi_rdata    ( m_MBUS_dwidth_conv_to_clock_conv_axi_rdata    ),
        .s_axi_rresp    ( m_MBUS_dwidth_conv_to_clock_conv_axi_rresp    ),
        .s_axi_rlast    ( m_MBUS_dwidth_conv_to_clock_conv_axi_rlast    ),
        .s_axi_rvalid   ( m_MBUS_dwidth_conv_to_clock_conv_axi_rvalid   ),
        .s_axi_rready   ( m_MBUS_dwidth_conv_to_clock_conv_axi_rready   ),

        // Master to MBUS
        .m_axi_aclk     ( main_clock_i        ),
        .m_axi_aresetn  ( main_reset_ni       ),
        .m_axi_awid     ( m_MBUS_axi_awid     ),
        .m_axi_awaddr   ( m_MBUS_axi_awaddr   ),
        .m_axi_awlen    ( m_MBUS_axi_awlen    ),
        .m_axi_awsize   ( m_MBUS_axi_awsize   ),
        .m_axi_awburst  ( m_MBUS_axi_awburst  ),
        .m_axi_awlock   ( m_MBUS_axi_awlock   ),
        .m_axi_awcache  ( m_MBUS_axi_awcache  ),
        .m_axi_awprot   ( m_MBUS_axi_awprot   ),
        .m_axi_awregion ( m_MBUS_axi_awregion ),
        .m_axi_awqos    ( m_MBUS_axi_awqos    ),
        .m_axi_awvalid  ( m_MBUS_axi_awvalid  ),
        .m_axi_awready  ( m_MBUS_axi_awready  ),
        .m_axi_wdata    ( m_MBUS_axi_wdata    ),
        .m_axi_wstrb    ( m_MBUS_axi_wstrb    ),
        .m_axi_wlast    ( m_MBUS_axi_wlast    ),
        .m_axi_wvalid   ( m_MBUS_axi_wvalid   ),
        .m_axi_wready   ( m_MBUS_axi_wready   ),
        .m_axi_bid      ( m_MBUS_axi_bid      ),
        .m_axi_bresp    ( m_MBUS_axi_bresp    ),
        .m_axi_bvalid   ( m_MBUS_axi_bvalid   ),
        .m_axi_bready   ( m_MBUS_axi_bready   ),
        .m_axi_arid     ( m_MBUS_axi_arid     ),
        .m_axi_araddr   ( m_MBUS_axi_araddr   ),
        .m_axi_arlen    ( m_MBUS_axi_arlen    ),
        .m_axi_arsize   ( m_MBUS_axi_arsize   ),
        .m_axi_arburst  ( m_MBUS_axi_arburst  ),
        .m_axi_arlock   ( m_MBUS_axi_arlock   ),
        .m_axi_arcache  ( m_MBUS_axi_arcache  ),
        .m_axi_arprot   ( m_MBUS_axi_arprot   ),
        .m_axi_arregion ( m_MBUS_axi_arregion ),
        .m_axi_arqos    ( m_MBUS_axi_arqos    ),
        .m_axi_arvalid  ( m_MBUS_axi_arvalid  ),
        .m_axi_arready  ( m_MBUS_axi_arready  ),
        .m_axi_rid      ( m_MBUS_axi_rid      ),
        .m_axi_rdata    ( m_MBUS_axi_rdata    ),
        .m_axi_rresp    ( m_MBUS_axi_rresp    ),
        .m_axi_rlast    ( m_MBUS_axi_rlast    ),
        .m_axi_rvalid   ( m_MBUS_axi_rvalid   ),
        .m_axi_rready   ( m_MBUS_axi_rready   )
    );

    ///////////////////
    // AXI4 Crossbar //
    ///////////////////

    // Connnect to config-generated buses
    `ASSIGN_AXI_BUS(s_acc_to_HBUS, s_acc)
    `ASSIGN_AXI_BUS(MBUS_to_HBUS, dwidth_conv_to_HBUS)
    `ASSIGN_AXI_BUS(dwidth_conv_from_HBUS, HBUS_to_MBUS)

    // AXI4 crossbar
    xlnx_highperformance_crossbar highperformance_xbar_u (
        .aclk           ( HBUS_clk                  ),
        .aresetn        ( HBUS_rstn                 ),
        .s_axi_awid     ( HBUS_masters_axi_awid     ), // input
        .s_axi_awaddr   ( HBUS_masters_axi_awaddr   ), // input
        .s_axi_awlen    ( HBUS_masters_axi_awlen    ), // input
        .s_axi_awsize   ( HBUS_masters_axi_awsize   ), // input
        .s_axi_awburst  ( HBUS_masters_axi_awburst  ), // input
        .s_axi_awlock   ( HBUS_masters_axi_awlock   ), // input
        .s_axi_awcache  ( HBUS_masters_axi_awcache  ), // input
        .s_axi_awprot   ( HBUS_masters_axi_awprot   ), // input
        .s_axi_awqos    ( HBUS_masters_axi_awqos    ), // input
        .s_axi_awvalid  ( HBUS_masters_axi_awvalid  ), // input
        .s_axi_awready  ( HBUS_masters_axi_awready  ), // output
        .s_axi_wdata    ( HBUS_masters_axi_wdata    ), // input
        .s_axi_wstrb    ( HBUS_masters_axi_wstrb    ), // input
        .s_axi_wlast    ( HBUS_masters_axi_wlast    ), // input
        .s_axi_wvalid   ( HBUS_masters_axi_wvalid   ), // input
        .s_axi_wready   ( HBUS_masters_axi_wready   ), // output
        .s_axi_bid      ( HBUS_masters_axi_bid      ), // output
        .s_axi_bresp    ( HBUS_masters_axi_bresp    ), // output
        .s_axi_bvalid   ( HBUS_masters_axi_bvalid   ), // output
        .s_axi_bready   ( HBUS_masters_axi_bready   ), // input
        .s_axi_arid     ( HBUS_masters_axi_arid     ), // output
        .s_axi_araddr   ( HBUS_masters_axi_araddr   ), // input
        .s_axi_arlen    ( HBUS_masters_axi_arlen    ), // input
        .s_axi_arsize   ( HBUS_masters_axi_arsize   ), // input
        .s_axi_arburst  ( HBUS_masters_axi_arburst  ), // input
        .s_axi_arlock   ( HBUS_masters_axi_arlock   ), // input
        .s_axi_arcache  ( HBUS_masters_axi_arcache  ), // input
        .s_axi_arprot   ( HBUS_masters_axi_arprot   ), // input
        .s_axi_arqos    ( HBUS_masters_axi_arqos    ), // input
        .s_axi_arvalid  ( HBUS_masters_axi_arvalid  ), // input
        .s_axi_arready  ( HBUS_masters_axi_arready  ), // output
        .s_axi_rid      ( HBUS_masters_axi_rid      ), // output
        .s_axi_rdata    ( HBUS_masters_axi_rdata    ), // output
        .s_axi_rresp    ( HBUS_masters_axi_rresp    ), // output
        .s_axi_rlast    ( HBUS_masters_axi_rlast    ), // output
        .s_axi_rvalid   ( HBUS_masters_axi_rvalid   ), // output
        .s_axi_rready   ( HBUS_masters_axi_rready   ), // input
        .m_axi_awid     ( HBUS_slaves_axi_awid      ), // output
        .m_axi_awaddr   ( HBUS_slaves_axi_awaddr    ), // output
        .m_axi_awlen    ( HBUS_slaves_axi_awlen     ), // output
        .m_axi_awsize   ( HBUS_slaves_axi_awsize    ), // output
        .m_axi_awburst  ( HBUS_slaves_axi_awburst   ), // output
        .m_axi_awlock   ( HBUS_slaves_axi_awlock    ), // output
        .m_axi_awcache  ( HBUS_slaves_axi_awcache   ), // output
        .m_axi_awprot   ( HBUS_slaves_axi_awprot    ), // output
        .m_axi_awregion ( HBUS_slaves_axi_awregion  ), // output
        .m_axi_awqos    ( HBUS_slaves_axi_awqos     ), // output
        .m_axi_awvalid  ( HBUS_slaves_axi_awvalid   ), // output
        .m_axi_awready  ( HBUS_slaves_axi_awready   ), // input
        .m_axi_wdata    ( HBUS_slaves_axi_wdata     ), // output
        .m_axi_wstrb    ( HBUS_slaves_axi_wstrb     ), // output
        .m_axi_wlast    ( HBUS_slaves_axi_wlast     ), // output
        .m_axi_wvalid   ( HBUS_slaves_axi_wvalid    ), // output
        .m_axi_wready   ( HBUS_slaves_axi_wready    ), // input
        .m_axi_bid      ( HBUS_slaves_axi_bid       ), // input
        .m_axi_bresp    ( HBUS_slaves_axi_bresp     ), // input
        .m_axi_bvalid   ( HBUS_slaves_axi_bvalid    ), // input
        .m_axi_bready   ( HBUS_slaves_axi_bready    ), // output
        .m_axi_arid     ( HBUS_slaves_axi_arid      ), // output
        .m_axi_araddr   ( HBUS_slaves_axi_araddr    ), // output
        .m_axi_arlen    ( HBUS_slaves_axi_arlen     ), // output
        .m_axi_arsize   ( HBUS_slaves_axi_arsize    ), // output
        .m_axi_arburst  ( HBUS_slaves_axi_arburst   ), // output
        .m_axi_arlock   ( HBUS_slaves_axi_arlock    ), // output
        .m_axi_arcache  ( HBUS_slaves_axi_arcache   ), // output
        .m_axi_arprot   ( HBUS_slaves_axi_arprot    ), // output
        .m_axi_arregion ( HBUS_slaves_axi_arregion  ), // output
        .m_axi_arqos    ( HBUS_slaves_axi_arqos     ), // output
        .m_axi_arvalid  ( HBUS_slaves_axi_arvalid   ), // output
        .m_axi_arready  ( HBUS_slaves_axi_arready   ), // input
        .m_axi_rid      ( HBUS_slaves_axi_rid       ), // input
        .m_axi_rdata    ( HBUS_slaves_axi_rdata     ), // input
        .m_axi_rresp    ( HBUS_slaves_axi_rresp     ), // input
        .m_axi_rlast    ( HBUS_slaves_axi_rlast     ), // input
        .m_axi_rvalid   ( HBUS_slaves_axi_rvalid    ), // input
        .m_axi_rready   ( HBUS_slaves_axi_rready    )  // output
    );


    /////////////////
    // AXI4 Slaves //
    /////////////////

    // TODO: this is just a single DDR4 channel for now
    // TODO: generate over NUM_DDR_CHANNELS
    // TODO: integrate HBM a well and generate over NUM_HBM_CHANNELS

    // Synch DDR4 sys reset - it is active high
    logic ddr4_reset = 1'b1;
    always @(posedge main_clock_i or negedge main_reset_ni) begin
        if (main_reset_ni == 1'b0) begin
            ddr4_reset <= 1'b1;
        end else begin
            ddr4_reset <= 1'b0;
        end
    end

    // Tie-off floaintg nets
    assign dwidth_conv_to_HBUS_axi_arid                  = '0;
    // assign dwidth_conv_to_HBUS_axi_arregion              = '0;
    assign dwidth_conv_to_HBUS_axi_awid                  = '0;
    // assign dwidth_conv_to_HBUS_axi_awregion              = '0;
    assign m_MBUS_dwidth_conv_to_clock_conv_axi_arid     = '0;
    // assign m_MBUS_dwidth_conv_to_clock_conv_axi_arregion = '0;
    assign m_MBUS_dwidth_conv_to_clock_conv_axi_awid     = '0;
    // assign m_MBUS_dwidth_conv_to_clock_conv_axi_awregion = '0;

    // DDR4 Channel 0
    xlnx_ddr4 ddr4_u (
        .c0_sys_clk_n                ( clk_300mhz_x_n_i ),
        .c0_sys_clk_p                ( clk_300mhz_x_p_i ),

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
        .c0_ddr4_parity              ( cx_ddr4_parity   ),
        .c0_ddr4_bg                  ( cx_ddr4_bg       ),
        .c0_ddr4_reset_n             ( cx_ddr4_reset_n  ),
        .c0_ddr4_act_n               ( cx_ddr4_act_n    ),
        .c0_ddr4_ck_t                ( cx_ddr4_ck_t     ),
        .c0_ddr4_ck_c                ( cx_ddr4_ck_c     ),

        .c0_ddr4_ui_clk              ( ddr_clk          ),
        .c0_ddr4_ui_clk_sync_rst     ( ddr_rst          ),

        .c0_ddr4_aresetn             ( ~ddr_rst         ), // Feed-back as AXI reset

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
        // .c0_ddr4_s_axi_ctrl_arprot   ( s_ctrl_axilite_arprot  ), // Ports not implemented
        // .c0_ddr4_s_axi_ctrl_awprot   ( s_ctrl_axilite_awprot  ), // Ports not implemented
        // .c0_ddr4_s_axi_ctrl_wstrb    ( s_ctrl_axilite_wstrb   ), // Ports not implemented


        // AXI4 interface
        .c0_ddr4_s_axi_awid          ( HBUS_to_DDR4CH0_axi_awid    ),
        .c0_ddr4_s_axi_awaddr        ( { 2'b00, HBUS_to_DDR4CH0_axi_awaddr } ), // 34 bits
        .c0_ddr4_s_axi_awlen         ( HBUS_to_DDR4CH0_axi_awlen   ),
        .c0_ddr4_s_axi_awsize        ( HBUS_to_DDR4CH0_axi_awsize  ),
        .c0_ddr4_s_axi_awburst       ( HBUS_to_DDR4CH0_axi_awburst ),
        .c0_ddr4_s_axi_awlock        ( HBUS_to_DDR4CH0_axi_awlock  ),
        .c0_ddr4_s_axi_awcache       ( HBUS_to_DDR4CH0_axi_awcache ),
        .c0_ddr4_s_axi_awprot        ( HBUS_to_DDR4CH0_axi_awprot  ),
        .c0_ddr4_s_axi_awqos         ( HBUS_to_DDR4CH0_axi_awqos   ),
        .c0_ddr4_s_axi_awvalid       ( HBUS_to_DDR4CH0_axi_awvalid ),
        .c0_ddr4_s_axi_awready       ( HBUS_to_DDR4CH0_axi_awready ),
        .c0_ddr4_s_axi_wdata         ( HBUS_to_DDR4CH0_axi_wdata   ),
        .c0_ddr4_s_axi_wstrb         ( HBUS_to_DDR4CH0_axi_wstrb   ),
        .c0_ddr4_s_axi_wlast         ( HBUS_to_DDR4CH0_axi_wlast   ),
        .c0_ddr4_s_axi_wvalid        ( HBUS_to_DDR4CH0_axi_wvalid  ),
        .c0_ddr4_s_axi_wready        ( HBUS_to_DDR4CH0_axi_wready  ),
        .c0_ddr4_s_axi_bready        ( HBUS_to_DDR4CH0_axi_bready  ),
        .c0_ddr4_s_axi_bid           ( HBUS_to_DDR4CH0_axi_bid     ),
        .c0_ddr4_s_axi_bresp         ( HBUS_to_DDR4CH0_axi_bresp   ),
        .c0_ddr4_s_axi_bvalid        ( HBUS_to_DDR4CH0_axi_bvalid  ),
        .c0_ddr4_s_axi_arid          ( HBUS_to_DDR4CH0_axi_arid    ),
        .c0_ddr4_s_axi_araddr        ( { 2'b00, HBUS_to_DDR4CH0_axi_araddr } ), // 34 bits
        .c0_ddr4_s_axi_arlen         ( HBUS_to_DDR4CH0_axi_arlen   ),
        .c0_ddr4_s_axi_arsize        ( HBUS_to_DDR4CH0_axi_arsize  ),
        .c0_ddr4_s_axi_arburst       ( HBUS_to_DDR4CH0_axi_arburst ),
        .c0_ddr4_s_axi_arlock        ( HBUS_to_DDR4CH0_axi_arlock  ),
        .c0_ddr4_s_axi_arcache       ( HBUS_to_DDR4CH0_axi_arcache ),
        .c0_ddr4_s_axi_arprot        ( HBUS_to_DDR4CH0_axi_arprot  ),
        .c0_ddr4_s_axi_arqos         ( HBUS_to_DDR4CH0_axi_arqos   ),
        .c0_ddr4_s_axi_arvalid       ( HBUS_to_DDR4CH0_axi_arvalid ),
        .c0_ddr4_s_axi_arready       ( HBUS_to_DDR4CH0_axi_arready ),
        .c0_ddr4_s_axi_rready        ( HBUS_to_DDR4CH0_axi_rready  ),
        .c0_ddr4_s_axi_rlast         ( HBUS_to_DDR4CH0_axi_rlast   ),
        .c0_ddr4_s_axi_rvalid        ( HBUS_to_DDR4CH0_axi_rvalid  ),
        .c0_ddr4_s_axi_rresp         ( HBUS_to_DDR4CH0_axi_rresp   ),
        .c0_ddr4_s_axi_rid           ( HBUS_to_DDR4CH0_axi_rid     ),
        .c0_ddr4_s_axi_rdata         ( HBUS_to_DDR4CH0_axi_rdata   )
    );

endmodule : highperformance_bus
