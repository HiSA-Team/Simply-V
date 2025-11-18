// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description: Sub-system for HLS IPs. Currently, only replication of homogeneous IPs is supported.

// Import headers
`include "uninasoc_axi.svh"


// Assign master bus interface to port
`define ASSIGN_AXI_PORT(port_name, bus_name)                    \
    .``port_name``_axi_awid     ( ``bus_name``_axi_awid      ), \
    .``port_name``_axi_awaddr   ( ``bus_name``_axi_awaddr    ), \
    .``port_name``_axi_awlen    ( ``bus_name``_axi_awlen     ), \
    .``port_name``_axi_awsize   ( ``bus_name``_axi_awsize    ), \
    .``port_name``_axi_awburst  ( ``bus_name``_axi_awburst   ), \
    .``port_name``_axi_awlock   ( ``bus_name``_axi_awlock    ), \
    .``port_name``_axi_awcache  ( ``bus_name``_axi_awcache   ), \
    .``port_name``_axi_awprot   ( ``bus_name``_axi_awprot    ), \
    .``port_name``_axi_awqos    ( ``bus_name``_axi_awqos     ), \
    .``port_name``_axi_awvalid  ( ``bus_name``_axi_awvalid   ), \
    .``port_name``_axi_awregion ( ``bus_name``_axi_awregion  ), \
    .``port_name``_axi_wdata    ( ``bus_name``_axi_wdata     ), \
    .``port_name``_axi_wstrb    ( ``bus_name``_axi_wstrb     ), \
    .``port_name``_axi_wlast    ( ``bus_name``_axi_wlast     ), \
    .``port_name``_axi_wvalid   ( ``bus_name``_axi_wvalid    ), \
    .``port_name``_axi_araddr   ( ``bus_name``_axi_araddr    ), \
    .``port_name``_axi_arlen    ( ``bus_name``_axi_arlen     ), \
    .``port_name``_axi_arsize   ( ``bus_name``_axi_arsize    ), \
    .``port_name``_axi_arburst  ( ``bus_name``_axi_arburst   ), \
    .``port_name``_axi_arlock   ( ``bus_name``_axi_arlock    ), \
    .``port_name``_axi_arcache  ( ``bus_name``_axi_arcache   ), \
    .``port_name``_axi_arprot   ( ``bus_name``_axi_arprot    ), \
    .``port_name``_axi_arqos    ( ``bus_name``_axi_arqos     ), \
    .``port_name``_axi_arvalid  ( ``bus_name``_axi_arvalid   ), \
    .``port_name``_axi_arid     ( ``bus_name``_axi_arid      ), \
    .``port_name``_axi_arregion ( ``bus_name``_axi_arregion  ), \
    .``port_name``_axi_rready   ( ``bus_name``_axi_rready    ), \
    .``port_name``_axi_bready   ( ``bus_name``_axi_bready    ), \
    .``port_name``_axi_awready  ( ``bus_name``_axi_awready   ), \
    .``port_name``_axi_wready   ( ``bus_name``_axi_wready    ), \
    .``port_name``_axi_bid      ( ``bus_name``_axi_bid       ), \
    .``port_name``_axi_bresp    ( ``bus_name``_axi_bresp     ), \
    .``port_name``_axi_bvalid   ( ``bus_name``_axi_bvalid    ), \
    .``port_name``_axi_arready  ( ``bus_name``_axi_arready   ), \
    .``port_name``_axi_rid      ( ``bus_name``_axi_rid       ), \
    .``port_name``_axi_rdata    ( ``bus_name``_axi_rdata     ), \
    .``port_name``_axi_rresp    ( ``bus_name``_axi_rresp     ), \
    .``port_name``_axi_rlast    ( ``bus_name``_axi_rlast     ), \
    .``port_name``_axi_rvalid   ( ``bus_name``_axi_rvalid    )


module hls_subsystem # (
    // MBUS parameters, for HLS_CTRL
    parameter MBUS_ADDR_WIDTH = 32,
    parameter MBUS_DATA_WIDTH = 32,
    parameter MBUS_ID_WIDTH   = 4,
    // HBUS parameters
    parameter AXI_MASTER_DATA_WIDTH = 512,
    parameter AXI_MASTER_ADDR_WIDTH = 32,
    parameter AXI_MASTER_ID_WIDTH   = 4,
    // Number of instances
    parameter NUM_HLS_CORES = 1 // Supported values are 1, 2, 4, 8
) (
    // MBUS clock and reset (for CDC)
    input  logic main_clk_i,
    input  logic main_rstn_i,

    // HLS IP(s) clock and reset
    input  logic [NUM_HLS_CORES -1 : 0] HLS_CTRL_clk_i,
    input  logic [NUM_HLS_CORES -1 : 0] HLS_CTRL_rstn_i,

    // Slave(s) for control
    `DEFINE_AXI_SLAVE_PORTS(s_HLS_CTRL0, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),
    `DEFINE_AXI_SLAVE_PORTS(s_HLS_CTRL1, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),
    `DEFINE_AXI_SLAVE_PORTS(s_HLS_CTRL2, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),
    `DEFINE_AXI_SLAVE_PORTS(s_HLS_CTRL3, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),
    `DEFINE_AXI_SLAVE_PORTS(s_HLS_CTRL4, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),
    `DEFINE_AXI_SLAVE_PORTS(s_HLS_CTRL5, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),
    `DEFINE_AXI_SLAVE_PORTS(s_HLS_CTRL6, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),
    `DEFINE_AXI_SLAVE_PORTS(s_HLS_CTRL7, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),

    // Master(s) to MBUS / HBUS
    `DEFINE_AXI_MASTER_PORTS(m0, AXI_MASTER_DATA_WIDTH, AXI_MASTER_ADDR_WIDTH, AXI_MASTER_ID_WIDTH),
    `DEFINE_AXI_MASTER_PORTS(m1, AXI_MASTER_DATA_WIDTH, AXI_MASTER_ADDR_WIDTH, AXI_MASTER_ID_WIDTH),
    `DEFINE_AXI_MASTER_PORTS(m2, AXI_MASTER_DATA_WIDTH, AXI_MASTER_ADDR_WIDTH, AXI_MASTER_ID_WIDTH),
    `DEFINE_AXI_MASTER_PORTS(m3, AXI_MASTER_DATA_WIDTH, AXI_MASTER_ADDR_WIDTH, AXI_MASTER_ID_WIDTH),
    `DEFINE_AXI_MASTER_PORTS(m4, AXI_MASTER_DATA_WIDTH, AXI_MASTER_ADDR_WIDTH, AXI_MASTER_ID_WIDTH),
    `DEFINE_AXI_MASTER_PORTS(m5, AXI_MASTER_DATA_WIDTH, AXI_MASTER_ADDR_WIDTH, AXI_MASTER_ID_WIDTH),
    `DEFINE_AXI_MASTER_PORTS(m6, AXI_MASTER_DATA_WIDTH, AXI_MASTER_ADDR_WIDTH, AXI_MASTER_ID_WIDTH),
    `DEFINE_AXI_MASTER_PORTS(m7, AXI_MASTER_DATA_WIDTH, AXI_MASTER_ADDR_WIDTH, AXI_MASTER_ID_WIDTH),

    // Interrupt line(s)
    output logic [NUM_HLS_CORES -1 : 0] hls_interrupt_o
);

    //////////////////
    // Local macros //
    //////////////////

    // Parameters for HLS wrappers
    `define HLS_WRAPPER_PARAMETERS \
        // MBUS parameters                                \
        .MBUS_ADDR_WIDTH ( MBUS_ADDR_WIDTH ),             \
        .MBUS_DATA_WIDTH ( MBUS_DATA_WIDTH ),             \
        .MBUS_ID_WIDTH   ( MBUS_ID_WIDTH   ),             \
        // HLS MASTER parameters                          \
        .AXI_MASTER_DATA_WIDTH ( AXI_MASTER_DATA_WIDTH ), \
        .AXI_MASTER_ADDR_WIDTH ( AXI_MASTER_ADDR_WIDTH ), \
        .AXI_MASTER_ID_WIDTH   ( AXI_MASTER_ID_WIDTH   )

    // Clock, reset and interrupt port map for HLS wrappers
    `define HLS_WRAPPER_BASIC_PORT_MAP(idx)                            \
            // MBUS clock and reset                                    \
            .main_clk_i                 ( main_clk_i  ),               \
            .main_rstn_i                ( main_rstn_i ),               \
            // HLS IP clock and reset                                  \
            .HLS_CTRL_clk_i          ( HLS_CTRL_clk_i  [``idx``] ), \
            .HLS_CTRL_rstn_i         ( HLS_CTRL_rstn_i [``idx``] ), \
            // Interrupt                                               \
            .hls_interrupt_o            ( hls_interrupt_o [``idx``] )

    // Instantiatuon of a single HLS wrapper
    `define HLS_WRAPPER_INSTANCE(idx)                                 \
            hls_wrapper # (                                           \
                `HLS_WRAPPER_PARAMETERS                               \
            ) hls_wrapper``idx``_u (                                  \
                `HLS_WRAPPER_BASIC_PORT_MAP(``idx``),                 \
                // Slave for control                                  \
                `ASSIGN_AXI_PORT( s_HLS_CTRL, s_HLS_CTRL``idx`` ), \
                // Master to MBUS / HBUS                              \
                `ASSIGN_AXI_PORT( m, m``idx`` )                       \
            );


    // Generate HLS cores array manually
    // NOTE: pre-processor macros for AXI buses are evaluated before genvars, therefore a generate for cannot be used here.
    generate
        if ( NUM_HLS_CORES >= 1 ) begin : gen_hls1
            // Module istance 0, assume uniform parameters
            `HLS_WRAPPER_INSTANCE(0)
        end : gen_hls1
        if ( NUM_HLS_CORES >= 2 ) begin : gen_hls2
            // Module istance 1, assume uniform parameters
            `HLS_WRAPPER_INSTANCE(1)
        end : gen_hls2
        if ( NUM_HLS_CORES >= 4 ) begin : gen_hls4
            // Module istance 2, assume uniform parameters
            `HLS_WRAPPER_INSTANCE(2)
            // Module istance 3, assume uniform parameters
            `HLS_WRAPPER_INSTANCE(3)
        end : gen_hls4
        if ( NUM_HLS_CORES >= 8 ) begin : gen_hls8
            // Module istance 4, assume uniform parameters
            `HLS_WRAPPER_INSTANCE(4)
            // Module istance 5, assume uniform parameters
            `HLS_WRAPPER_INSTANCE(5)
            // Module istance 6, assume uniform parameters
            `HLS_WRAPPER_INSTANCE(6)
            // Module istance 7, assume uniform parameters
            `HLS_WRAPPER_INSTANCE(7)
        end : gen_hls8

    endgenerate


endmodule : hls_subsystem