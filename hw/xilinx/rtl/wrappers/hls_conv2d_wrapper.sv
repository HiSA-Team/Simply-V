// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
//  Wrapper module for HLS CONV2D IP with clock bridges an AXI adapters.
// Note:
//  This is static for now, but could be extended to a generic shell for HLS IP, with CDC support, multiple interfaces, etc.
//
// Architecture: HLS IP integration (with CDC)
//    ____________________________
//   |                            |
//   |   axi_clock_converter_u    |<-------------------- HLSCONTROL (from MBUS)
//   |____________________________|
//        |
//        | sync_HLSCONTROL (HBUS clock domain)
//    ____V_________________
//   |                      |
//   |   axi_dwidth_conv_u  |
//   |     (XLEN == 64)     |
//   |______________________|
//        |
//        | d32_HLSCONTROL (HBUS clock domain)
//    ____v_______________________
//   |                            |
//   |   xlnx_axi4_to_axilite_u   |
//   |____________________________|
//        |
//        | HLSCONTROL_axilite
//        |         ________
//        |        |        |  HLS_gmem0_d512
//        \------->|        |------------------------------------> HLS_gmem0_d512 (to HBUS)
//                 | HLS IP |                   ______________
//                 |        |  interrupt       |              | (MBUS clock domain)
//                 |        |----------------->| synchronizer |--> to PLIC
//                 |________|                  |______________|
//

module hls_conv2d_wrapper # (
    // MBUS parameters
    parameter MBUS_ADDR_WIDTH = 32,
    parameter MBUS_DATA_WIDTH = 32,
    parameter MBUS_ID_WIDTH   = 4,
    // HBUS parameters
    parameter HBUS_DATA_WIDTH = 512,
    parameter HBUS_ADDR_WIDTH = 32,
    parameter HBUS_ID_WIDTH   = 4
) (
    // MBUS clock and reset
    input  logic main_clk_i,
    input  logic main_rstn_i,

    // HLS IP clock and reset (from HBUS)
    input  logic HLSCONTROL_clk_i,
    input  logic HLSCONTROL_rstn_i,

    // Slave for control
    `DEFINE_AXI_SLAVE_PORTS(s_HLSCONTROL, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),

    // Master to HBUS
    `DEFINE_AXI_MASTER_PORTS(m_HLS_gmem0_d512, HBUS_DATA_WIDTH, HBUS_ADDR_WIDTH, HBUS_ID_WIDTH),

    // Interrupt
    output logic hls_interrupt_o

);

    //////////////////
    // Declarations //
    //////////////////

    // HLS interrupt line (not synchronized to MBUS)
    logic hls_interrupt_async;

    // axi_clock_converter_u -> axi_dwidth_conv_u
    `DECLARE_AXI_BUS(sync_HLSCONTROL, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH);

    // axi_dwidth_conv_u -> xlnx_axi4_to_axilite_u
    localparam int unsigned HLS_DATA_WIDTH = 32;
    localparam int unsigned HLS_ADDR_WIDTH = 32; // NOTE: this is goig to clip
    localparam int unsigned HLS_ID_WIDTH = MBUS_ID_WIDTH;
    `DECLARE_AXI_BUS(to_prot_conv, HLS_DATA_WIDTH, HLS_ADDR_WIDTH, MBUS_ID_WIDTH);

    // HLS_DOTPROD_CONTROL AXI-lite
    // xlnx_axi4_to_axilite_u -> custom_hls_conv_hbus_u
    `DECLARE_AXILITE_BUS(HLSCONTROL, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH);

    /////////////
    // Modules //
    /////////////

    // Add clock bridges for HLSCONTROL
    `ifdef HLSCONTROL_HAS_CLOCK_DOMAIN
        // s_HLSCONTROL -> sync_HLSCONTROL
        axi_clock_converter_wrapper # (
            .LOCAL_DATA_WIDTH   ( MBUS_DATA_WIDTH ),
            .LOCAL_ADDR_WIDTH   ( MBUS_ADDR_WIDTH ),
            .LOCAL_ID_WIDTH     ( MBUS_ID_WIDTH   )
        ) axi_clock_converter_u (
            // AXI4 Slave from MBUS
            .s_axi_aclk     ( main_clk_i  ),
            .s_axi_aresetn  ( main_rstn_i ),
            .s_axi_awid     ( s_HLSCONTROL_axi_awid     ),
            .s_axi_awaddr   ( s_HLSCONTROL_axi_awaddr   ),
            .s_axi_awlen    ( s_HLSCONTROL_axi_awlen    ),
            .s_axi_awsize   ( s_HLSCONTROL_axi_awsize   ),
            .s_axi_awburst  ( s_HLSCONTROL_axi_awburst  ),
            .s_axi_awlock   ( s_HLSCONTROL_axi_awlock   ),
            .s_axi_awcache  ( s_HLSCONTROL_axi_awcache  ),
            .s_axi_awprot   ( s_HLSCONTROL_axi_awprot   ),
            .s_axi_awqos    ( s_HLSCONTROL_axi_awqos    ),
            .s_axi_awvalid  ( s_HLSCONTROL_axi_awvalid  ),
            .s_axi_awready  ( s_HLSCONTROL_axi_awready  ),
            .s_axi_awregion ( s_HLSCONTROL_axi_awregion ),
            .s_axi_wdata    ( s_HLSCONTROL_axi_wdata    ),
            .s_axi_wstrb    ( s_HLSCONTROL_axi_wstrb    ),
            .s_axi_wlast    ( s_HLSCONTROL_axi_wlast    ),
            .s_axi_wvalid   ( s_HLSCONTROL_axi_wvalid   ),
            .s_axi_wready   ( s_HLSCONTROL_axi_wready   ),
            .s_axi_bid      ( s_HLSCONTROL_axi_bid      ),
            .s_axi_bresp    ( s_HLSCONTROL_axi_bresp    ),
            .s_axi_bvalid   ( s_HLSCONTROL_axi_bvalid   ),
            .s_axi_bready   ( s_HLSCONTROL_axi_bready   ),
            .s_axi_arid     ( s_HLSCONTROL_axi_arid     ),
            .s_axi_araddr   ( s_HLSCONTROL_axi_araddr   ),
            .s_axi_arlen    ( s_HLSCONTROL_axi_arlen    ),
            .s_axi_arsize   ( s_HLSCONTROL_axi_arsize   ),
            .s_axi_arburst  ( s_HLSCONTROL_axi_arburst  ),
            .s_axi_arlock   ( s_HLSCONTROL_axi_arlock   ),
            .s_axi_arregion ( s_HLSCONTROL_axi_arregion ),
            .s_axi_arcache  ( s_HLSCONTROL_axi_arcache  ),
            .s_axi_arprot   ( s_HLSCONTROL_axi_arprot   ),
            .s_axi_arqos    ( s_HLSCONTROL_axi_arqos    ),
            .s_axi_arvalid  ( s_HLSCONTROL_axi_arvalid  ),
            .s_axi_arready  ( s_HLSCONTROL_axi_arready  ),
            .s_axi_rid      ( s_HLSCONTROL_axi_rid      ),
            .s_axi_rdata    ( s_HLSCONTROL_axi_rdata    ),
            .s_axi_rresp    ( s_HLSCONTROL_axi_rresp    ),
            .s_axi_rlast    ( s_HLSCONTROL_axi_rlast    ),
            .s_axi_rvalid   ( s_HLSCONTROL_axi_rvalid   ),
            .s_axi_rready   ( s_HLSCONTROL_axi_rready   ),

            // ALI-lite master to HLS IP
            .m_axi_aclk     ( HLSCONTROL_clk_i  ),
            .m_axi_aresetn  ( HLSCONTROL_rstn_i ),
            .m_axi_awid     ( sync_HLSCONTROL_axi_awid      ),
            .m_axi_awaddr   ( sync_HLSCONTROL_axi_awaddr    ),
            .m_axi_awlen    ( sync_HLSCONTROL_axi_awlen     ),
            .m_axi_awsize   ( sync_HLSCONTROL_axi_awsize    ),
            .m_axi_awburst  ( sync_HLSCONTROL_axi_awburst   ),
            .m_axi_awlock   ( sync_HLSCONTROL_axi_awlock    ),
            .m_axi_awcache  ( sync_HLSCONTROL_axi_awcache   ),
            .m_axi_awprot   ( sync_HLSCONTROL_axi_awprot    ),
            .m_axi_awregion ( sync_HLSCONTROL_axi_awregion  ),
            .m_axi_awqos    ( sync_HLSCONTROL_axi_awqos     ),
            .m_axi_awvalid  ( sync_HLSCONTROL_axi_awvalid   ),
            .m_axi_awready  ( sync_HLSCONTROL_axi_awready   ),
            .m_axi_wdata    ( sync_HLSCONTROL_axi_wdata     ),
            .m_axi_wstrb    ( sync_HLSCONTROL_axi_wstrb     ),
            .m_axi_wlast    ( sync_HLSCONTROL_axi_wlast     ),
            .m_axi_wvalid   ( sync_HLSCONTROL_axi_wvalid    ),
            .m_axi_wready   ( sync_HLSCONTROL_axi_wready    ),
            .m_axi_bid      ( sync_HLSCONTROL_axi_bid       ),
            .m_axi_bresp    ( sync_HLSCONTROL_axi_bresp     ),
            .m_axi_bvalid   ( sync_HLSCONTROL_axi_bvalid    ),
            .m_axi_bready   ( sync_HLSCONTROL_axi_bready    ),
            .m_axi_arid     ( sync_HLSCONTROL_axi_arid      ),
            .m_axi_araddr   ( sync_HLSCONTROL_axi_araddr    ),
            .m_axi_arlen    ( sync_HLSCONTROL_axi_arlen     ),
            .m_axi_arsize   ( sync_HLSCONTROL_axi_arsize    ),
            .m_axi_arburst  ( sync_HLSCONTROL_axi_arburst   ),
            .m_axi_arlock   ( sync_HLSCONTROL_axi_arlock    ),
            .m_axi_arcache  ( sync_HLSCONTROL_axi_arcache   ),
            .m_axi_arprot   ( sync_HLSCONTROL_axi_arprot    ),
            .m_axi_arregion ( sync_HLSCONTROL_axi_arregion  ),
            .m_axi_arqos    ( sync_HLSCONTROL_axi_arqos     ),
            .m_axi_arvalid  ( sync_HLSCONTROL_axi_arvalid   ),
            .m_axi_arready  ( sync_HLSCONTROL_axi_arready   ),
            .m_axi_rid      ( sync_HLSCONTROL_axi_rid       ),
            .m_axi_rdata    ( sync_HLSCONTROL_axi_rdata     ),
            .m_axi_rresp    ( sync_HLSCONTROL_axi_rresp     ),
            .m_axi_rlast    ( sync_HLSCONTROL_axi_rlast     ),
            .m_axi_rvalid   ( sync_HLSCONTROL_axi_rvalid    ),
            .m_axi_rready   ( sync_HLSCONTROL_axi_rready    )
        );
    `else // notdefined(HLSCONTROL_HAS_CLOCK_DOMAIN)
        // Error out for now
        $error("This version of HLS CONV2D IP must be in HBUS clock domain");
    `endif

    // Use a Dwidth converter if System XLEN is 64-bits wide.
    generate
    if ( MBUS_DATA_WIDTH == 64 ) begin : gen_dwidth_conv

        xlnx_axi_dwidth_64_to_32_converter axi_dwidth_conv_u (
            .s_axi_aclk     ( HLSCONTROL_clk_i             ),
            .s_axi_aresetn  ( HLSCONTROL_rstn_i            ),

            // Slave from clock conv
            .s_axi_awid     ( sync_HLSCONTROL_axi_awid     ),
            .s_axi_awaddr   ( sync_HLSCONTROL_axi_awaddr   ),
            .s_axi_awlen    ( sync_HLSCONTROL_axi_awlen    ),
            .s_axi_awsize   ( sync_HLSCONTROL_axi_awsize   ),
            .s_axi_awburst  ( sync_HLSCONTROL_axi_awburst  ),
            .s_axi_awvalid  ( sync_HLSCONTROL_axi_awvalid  ),
            .s_axi_awready  ( sync_HLSCONTROL_axi_awready  ),
            .s_axi_wdata    ( sync_HLSCONTROL_axi_wdata    ),
            .s_axi_wstrb    ( sync_HLSCONTROL_axi_wstrb    ),
            .s_axi_wlast    ( sync_HLSCONTROL_axi_wlast    ),
            .s_axi_wvalid   ( sync_HLSCONTROL_axi_wvalid   ),
            .s_axi_wready   ( sync_HLSCONTROL_axi_wready   ),
            .s_axi_bid      ( sync_HLSCONTROL_axi_bid      ),
            .s_axi_bresp    ( sync_HLSCONTROL_axi_bresp    ),
            .s_axi_bvalid   ( sync_HLSCONTROL_axi_bvalid   ),
            .s_axi_bready   ( sync_HLSCONTROL_axi_bready   ),
            .s_axi_arid     ( sync_HLSCONTROL_axi_arid     ),
            .s_axi_araddr   ( sync_HLSCONTROL_axi_araddr   ),
            .s_axi_arlen    ( sync_HLSCONTROL_axi_arlen    ),
            .s_axi_arsize   ( sync_HLSCONTROL_axi_arsize   ),
            .s_axi_arburst  ( sync_HLSCONTROL_axi_arburst  ),
            .s_axi_arvalid  ( sync_HLSCONTROL_axi_arvalid  ),
            .s_axi_arready  ( sync_HLSCONTROL_axi_arready  ),
            .s_axi_rid      ( sync_HLSCONTROL_axi_rid      ),
            .s_axi_rdata    ( sync_HLSCONTROL_axi_rdata    ),
            .s_axi_rresp    ( sync_HLSCONTROL_axi_rresp    ),
            .s_axi_rlast    ( sync_HLSCONTROL_axi_rlast    ),
            .s_axi_rvalid   ( sync_HLSCONTROL_axi_rvalid   ),
            .s_axi_rready   ( sync_HLSCONTROL_axi_rready   ),
            .s_axi_awlock   ( sync_HLSCONTROL_axi_awlock   ),
            .s_axi_awcache  ( sync_HLSCONTROL_axi_awcache  ),
            .s_axi_awprot   ( sync_HLSCONTROL_axi_awprot   ),
            .s_axi_awqos    ( sync_HLSCONTROL_axi_awqos    ),
            .s_axi_awregion ( sync_HLSCONTROL_axi_awregion ),
            .s_axi_arlock   ( sync_HLSCONTROL_axi_arlock   ),
            .s_axi_arcache  ( sync_HLSCONTROL_axi_arcache  ),
            .s_axi_arprot   ( sync_HLSCONTROL_axi_arprot   ),
            .s_axi_arqos    ( sync_HLSCONTROL_arqos        ),
            .s_axi_arregion ( sync_HLSCONTROL_arregion     ),

            // Master to Protocol Converter
            .m_axi_awaddr   ( to_prot_conv_axi_awaddr  ),
            .m_axi_awlen    ( to_prot_conv_axi_awlen   ),
            .m_axi_awsize   ( to_prot_conv_axi_awsize  ),
            .m_axi_awburst  ( to_prot_conv_axi_awburst ),
            .m_axi_awlock   ( to_prot_conv_axi_awlock  ),
            .m_axi_awcache  ( to_prot_conv_axi_awcache ),
            .m_axi_awprot   ( to_prot_conv_axi_awprot  ),
            .m_axi_awqos    ( to_prot_conv_axi_awqos   ),
            .m_axi_awvalid  ( to_prot_conv_axi_awvalid ),
            .m_axi_awready  ( to_prot_conv_axi_awready ),
            .m_axi_wdata    ( to_prot_conv_axi_wdata   ),
            .m_axi_wstrb    ( to_prot_conv_axi_wstrb   ),
            .m_axi_wlast    ( to_prot_conv_axi_wlast   ),
            .m_axi_wvalid   ( to_prot_conv_axi_wvalid  ),
            .m_axi_wready   ( to_prot_conv_axi_wready  ),
            .m_axi_bresp    ( to_prot_conv_axi_bresp   ),
            .m_axi_bvalid   ( to_prot_conv_axi_bvalid  ),
            .m_axi_bready   ( to_prot_conv_axi_bready  ),
            .m_axi_araddr   ( to_prot_conv_axi_araddr  ),
            .m_axi_arlen    ( to_prot_conv_axi_arlen   ),
            .m_axi_arsize   ( to_prot_conv_axi_arsize  ),
            .m_axi_arburst  ( to_prot_conv_axi_arburst ),
            .m_axi_arlock   ( to_prot_conv_axi_arlock  ),
            .m_axi_arcache  ( to_prot_conv_axi_arcache ),
            .m_axi_arprot   ( to_prot_conv_axi_arprot  ),
            .m_axi_arqos    ( to_prot_conv_axi_arqos   ),
            .m_axi_arvalid  ( to_prot_conv_axi_arvalid ),
            .m_axi_arready  ( to_prot_conv_axi_arready ),
            .m_axi_rdata    ( to_prot_conv_axi_rdata   ),
            .m_axi_rresp    ( to_prot_conv_axi_rresp   ),
            .m_axi_rlast    ( to_prot_conv_axi_rlast   ),
            .m_axi_rvalid   ( to_prot_conv_axi_rvalid  ),
            .m_axi_rready   ( to_prot_conv_axi_rready  )

        );

        // Since the AXI data width converter has a reordering depth of 1 it doesn't have ID in its master ports - for more details see the documentation
        assign to_prot_conv_axi_awid = '0;
        assign to_prot_conv_axi_arid = '0;

    end : gen_dwidth_conv
    else begin : no_dwidth_conv

        // Pass through
        `ASSIGN_AXI_BUS (to_prot_conv, sync_HLSCONTROL)

    end : no_dwidth_conv
    endgenerate

    // AXI converter for HLS_DOTPROD_CONTROL
    xlnx_axi4_to_axilite_d32_converter xlnx_axi4_to_axilite_u (
        // Clock and reset
        .aclk               ( HLSCONTROL_clk_i         ), // input wire s_aclk
        .aresetn            ( HLSCONTROL_rstn_i        ), // input wire s_aresetn
        // Slave interface
        .s_axi_awid         ( to_prot_conv_axi_awid      ), // input wire [1 : 0] s_axi_awid
        .s_axi_awaddr       ( to_prot_conv_axi_awaddr    ), // input wire [31 : 0] s_axi_awaddr
        .s_axi_awlen        ( to_prot_conv_axi_awlen     ), // input wire [7 : 0] s_axi_awlen
        .s_axi_awsize       ( to_prot_conv_axi_awsize    ), // input wire [2 : 0] s_axi_awsize
        .s_axi_awburst      ( to_prot_conv_axi_awburst   ), // input wire [1 : 0] s_axi_awburst
        .s_axi_awlock       ( to_prot_conv_axi_awlock    ), // input wire [0 : 0] s_axi_awlock
        .s_axi_awcache      ( to_prot_conv_axi_awcache   ), // input wire [3 : 0] s_axi_awcache
        .s_axi_awprot       ( to_prot_conv_axi_awprot    ), // input wire [2 : 0] s_axi_awprot
        .s_axi_awregion     ( to_prot_conv_axi_awregion  ), // input wire [3 : 0] s_axi_awregion
        .s_axi_awqos        ( to_prot_conv_axi_awqos     ), // input wire [3 : 0] s_axi_awqos
        .s_axi_awvalid      ( to_prot_conv_axi_awvalid   ), // input wire s_axi_awvalid
        .s_axi_awready      ( to_prot_conv_axi_awready   ), // output wire s_axi_awready
        .s_axi_wdata        ( to_prot_conv_axi_wdata     ), // input wire [31 : 0] s_axi_wdata
        .s_axi_wstrb        ( to_prot_conv_axi_wstrb     ), // input wire [3 : 0] s_axi_wstrb
        .s_axi_wlast        ( to_prot_conv_axi_wlast     ), // input wire s_axi_wlast
        .s_axi_wvalid       ( to_prot_conv_axi_wvalid    ), // input wire s_axi_wvalid
        .s_axi_wready       ( to_prot_conv_axi_wready    ), // output wire s_axi_wready
        .s_axi_bid          ( to_prot_conv_axi_bid       ), // output wire [1 : 0] s_axi_bid
        .s_axi_bresp        ( to_prot_conv_axi_bresp     ), // output wire [1 : 0] s_axi_bresp
        .s_axi_bvalid       ( to_prot_conv_axi_bvalid    ), // output wire s_axi_bvalid
        .s_axi_bready       ( to_prot_conv_axi_bready    ), // input wire s_axi_bready
        .s_axi_arid         ( to_prot_conv_axi_arid      ), // input wire [1 : 0] s_axi_arid
        .s_axi_araddr       ( to_prot_conv_axi_araddr    ), // input wire [31 : 0] s_axi_araddr
        .s_axi_arlen        ( to_prot_conv_axi_arlen     ), // input wire [7 : 0] s_axi_arlen
        .s_axi_arsize       ( to_prot_conv_axi_arsize    ), // input wire [2 : 0] s_axi_arsize
        .s_axi_arburst      ( to_prot_conv_axi_arburst   ), // input wire [1 : 0] s_axi_arburst
        .s_axi_arlock       ( to_prot_conv_axi_arlock    ), // input wire [0 : 0] s_axi_arlock
        .s_axi_arcache      ( to_prot_conv_axi_arcache   ), // input wire [3 : 0] s_axi_arcache
        .s_axi_arprot       ( to_prot_conv_axi_arprot    ), // input wire [2 : 0] s_axi_arprot
        .s_axi_arregion     ( to_prot_conv_axi_arregion  ), // input wire [3 : 0] s_axi_arregion
        .s_axi_arqos        ( to_prot_conv_axi_arqos     ), // input wire [3 : 0] s_axi_arqos
        .s_axi_arvalid      ( to_prot_conv_axi_arvalid   ), // input wire s_axi_arvalid
        .s_axi_arready      ( to_prot_conv_axi_arready   ), // output wire s_axi_arready
        .s_axi_rid          ( to_prot_conv_axi_rid       ), // output wire [1 : 0] s_axi_rid
        .s_axi_rdata        ( to_prot_conv_axi_rdata     ), // output wire [31 : 0] s_axi_rdata
        .s_axi_rresp        ( to_prot_conv_axi_rresp     ), // output wire [1 : 0] s_axi_rresp
        .s_axi_rlast        ( to_prot_conv_axi_rlast     ), // output wire s_axi_rlast
        .s_axi_rvalid       ( to_prot_conv_axi_rvalid    ), // output wire s_axi_rvalid
        .s_axi_rready       ( to_prot_conv_axi_rready    ), // input wire s_axi_rready
        // Master interface
        .m_axi_awaddr       ( HLSCONTROL_axilite_awaddr        ), // output wire [31 : 0] m_axi_awaddr
        .m_axi_awprot       ( HLSCONTROL_axilite_awprot        ), // output wire [2 : 0] m_axi_awprot
        .m_axi_awvalid      ( HLSCONTROL_axilite_awvalid       ), // output wire m_axi_awvalid
        .m_axi_awready      ( HLSCONTROL_axilite_awready       ), // input wire m_axi_awready
        .m_axi_wdata        ( HLSCONTROL_axilite_wdata         ), // output wire [31 : 0] m_axi_wdata
        .m_axi_wstrb        ( HLSCONTROL_axilite_wstrb         ), // output wire [3 : 0] m_axi_wstrb
        .m_axi_wvalid       ( HLSCONTROL_axilite_wvalid        ), // output wire m_axi_wvalid
        .m_axi_wready       ( HLSCONTROL_axilite_wready        ), // input wire m_axi_wready
        .m_axi_bresp        ( HLSCONTROL_axilite_bresp         ), // input wire [1 : 0] m_axi_bresp
        .m_axi_bvalid       ( HLSCONTROL_axilite_bvalid        ), // input wire m_axi_bvalid
        .m_axi_bready       ( HLSCONTROL_axilite_bready        ), // output wire m_axi_bready
        .m_axi_araddr       ( HLSCONTROL_axilite_araddr        ), // output wire [31 : 0] m_axi_araddr
        .m_axi_arprot       ( HLSCONTROL_axilite_arprot        ), // output wire [2 : 0] m_axi_arprot
        .m_axi_arvalid      ( HLSCONTROL_axilite_arvalid       ), // output wire m_axi_arvalid
        .m_axi_arready      ( HLSCONTROL_axilite_arready       ), // input wire m_axi_arready
        .m_axi_rdata        ( HLSCONTROL_axilite_rdata         ), // input wire [31 : 0] m_axi_rdata
        .m_axi_rresp        ( HLSCONTROL_axilite_rresp         ), // input wire [1 : 0] m_axi_rresp
        .m_axi_rvalid       ( HLSCONTROL_axilite_rvalid        ), // input wire m_axi_rvalid
        .m_axi_rready       ( HLSCONTROL_axilite_rready        )  // output wire m_axi_rready
    );

    // Synchronize HLS interrupt line to MBUS
    xpm_cdc_array_single #(
        .DEST_SYNC_FF   ( 4 ),     // Number of sync flip-flops
        .SRC_INPUT_REG  ( 1 ),     // Input register enable
        .WIDTH          ( 1 )      // Width of data to sync
    )
    xpm_cdc_array_single_inst (
        .dest_out       ( hls_interrupt_o     ),
        .dest_clk       ( main_clk_i          ),
        .src_clk        ( HLSCONTROL_clk_i   ),
        .src_in         ( hls_interrupt_async )
    );

    // NOTE: AXI_DATA_WITDH=512 for this one, and should only be connected to HBUS
    // HLS core instance
    custom_hls_conv_hbus custom_hls_conv_hbus_u (
        .clk_i                      ( HLSCONTROL_clk_i            ), // input wire clk_i
        .rst_ni                     ( HLSCONTROL_rstn_i           ), // input wire rst_ni
        .interrupt_o                ( hls_interrupt_async          ), // output wire interrupt_o
        // AXI4 Master
        .gmem0_axi_awid             ( m_HLS_gmem0_d512_axi_awid      ),
        .gmem0_axi_awaddr           ( m_HLS_gmem0_d512_axi_awaddr    ),
        .gmem0_axi_awlen            ( m_HLS_gmem0_d512_axi_awlen     ),
        .gmem0_axi_awsize           ( m_HLS_gmem0_d512_axi_awsize    ),
        .gmem0_axi_awburst          ( m_HLS_gmem0_d512_axi_awburst   ),
        .gmem0_axi_awlock           ( m_HLS_gmem0_d512_axi_awlock    ),
        .gmem0_axi_awcache          ( m_HLS_gmem0_d512_axi_awcache   ),
        .gmem0_axi_awprot           ( m_HLS_gmem0_d512_axi_awprot    ),
        .gmem0_axi_awqos            ( m_HLS_gmem0_d512_axi_awqos     ),
        .gmem0_axi_awvalid          ( m_HLS_gmem0_d512_axi_awvalid   ),
        .gmem0_axi_awready          ( m_HLS_gmem0_d512_axi_awready   ),
        .gmem0_axi_awregion         ( m_HLS_gmem0_d512_axi_awregion  ),
        .gmem0_axi_wdata            ( m_HLS_gmem0_d512_axi_wdata     ),
        .gmem0_axi_wstrb            ( m_HLS_gmem0_d512_axi_wstrb     ),
        .gmem0_axi_wlast            ( m_HLS_gmem0_d512_axi_wlast     ),
        .gmem0_axi_wvalid           ( m_HLS_gmem0_d512_axi_wvalid    ),
        .gmem0_axi_wready           ( m_HLS_gmem0_d512_axi_wready    ),
        .gmem0_axi_bid              ( m_HLS_gmem0_d512_axi_bid       ),
        .gmem0_axi_bresp            ( m_HLS_gmem0_d512_axi_bresp     ),
        .gmem0_axi_bvalid           ( m_HLS_gmem0_d512_axi_bvalid    ),
        .gmem0_axi_bready           ( m_HLS_gmem0_d512_axi_bready    ),
        .gmem0_axi_araddr           ( m_HLS_gmem0_d512_axi_araddr    ),
        .gmem0_axi_arlen            ( m_HLS_gmem0_d512_axi_arlen     ),
        .gmem0_axi_arsize           ( m_HLS_gmem0_d512_axi_arsize    ),
        .gmem0_axi_arburst          ( m_HLS_gmem0_d512_axi_arburst   ),
        .gmem0_axi_arlock           ( m_HLS_gmem0_d512_axi_arlock    ),
        .gmem0_axi_arcache          ( m_HLS_gmem0_d512_axi_arcache   ),
        .gmem0_axi_arprot           ( m_HLS_gmem0_d512_axi_arprot    ),
        .gmem0_axi_arqos            ( m_HLS_gmem0_d512_axi_arqos     ),
        .gmem0_axi_arvalid          ( m_HLS_gmem0_d512_axi_arvalid   ),
        .gmem0_axi_arready          ( m_HLS_gmem0_d512_axi_arready   ),
        .gmem0_axi_arid             ( m_HLS_gmem0_d512_axi_arid      ),
        .gmem0_axi_arregion         ( m_HLS_gmem0_d512_axi_arregion  ),
        .gmem0_axi_rid              ( m_HLS_gmem0_d512_axi_rid       ),
        .gmem0_axi_rdata            ( m_HLS_gmem0_d512_axi_rdata     ),
        .gmem0_axi_rresp            ( m_HLS_gmem0_d512_axi_rresp     ),
        .gmem0_axi_rlast            ( m_HLS_gmem0_d512_axi_rlast     ),
        .gmem0_axi_rvalid           ( m_HLS_gmem0_d512_axi_rvalid    ),
        .gmem0_axi_rready           ( m_HLS_gmem0_d512_axi_rready    ),
        // HLSCONTROL AXI-lite slave
        .control_axilite_awaddr     ( HLSCONTROL_axilite_awaddr   ), // input wire [31 : 0] control_axilite_awaddr
        .control_axilite_awprot     ( HLSCONTROL_axilite_awprot   ), // input wire [2 : 0] control_axilite_awprot
        .control_axilite_awvalid    ( HLSCONTROL_axilite_awvalid  ), // input wire control_axilite_awvalid
        .control_axilite_awready    ( HLSCONTROL_axilite_awready  ), // output wire control_axilite_awready
        .control_axilite_wdata      ( HLSCONTROL_axilite_wdata    ), // input wire [31 : 0] control_axilite_wdata
        .control_axilite_wstrb      ( HLSCONTROL_axilite_wstrb    ), // input wire [3 : 0] control_axilite_wstrb
        .control_axilite_wvalid     ( HLSCONTROL_axilite_wvalid   ), // input wire control_axilite_wvalid
        .control_axilite_wready     ( HLSCONTROL_axilite_wready   ), // output wire control_axilite_wready
        .control_axilite_bresp      ( HLSCONTROL_axilite_bresp    ), // output wire [1 : 0] control_axilite_bresp
        .control_axilite_bvalid     ( HLSCONTROL_axilite_bvalid   ), // output wire control_axilite_bvalid
        .control_axilite_bready     ( HLSCONTROL_axilite_bready   ), // input wire control_axilite_bready
        .control_axilite_araddr     ( HLSCONTROL_axilite_araddr   ), // input wire [31 : 0] control_axilite_araddr
        .control_axilite_arprot     ( HLSCONTROL_axilite_arprot   ), // input wire [2 : 0] control_axilite_arprot
        .control_axilite_arvalid    ( HLSCONTROL_axilite_arvalid  ), // input wire control_axilite_arvalid
        .control_axilite_arready    ( HLSCONTROL_axilite_arready  ), // output wire control_axilite_arready
        .control_axilite_rdata      ( HLSCONTROL_axilite_rdata    ), // output wire [31 : 0] control_axilite_rdata
        .control_axilite_rresp      ( HLSCONTROL_axilite_rresp    ), // output wire [1 : 0] control_axilite_rresp
        .control_axilite_rvalid     ( HLSCONTROL_axilite_rvalid   ), // output wire control_axilite_rvalid
        .control_axilite_rready     ( HLSCONTROL_axilite_rready   )  // input wire control_axilite_rready
    );

endmodule : hls_conv2d_wrapper