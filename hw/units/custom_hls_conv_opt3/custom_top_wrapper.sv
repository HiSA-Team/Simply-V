// Author: Vincenzo Merola <vincenzo.merola2@unina.it>
// Description:
// This module is intended as a top-level wrapper for the code in ./rtl
// It might support either MEM protocol or AXI protocol, using the
// uninasoc_axi and uninasoc_mem svh files in hw/xilinx/rtl


// Import headers
`include "uninasoc_mem.svh"
`include "uninasoc_axi.svh"

module custom_top_wrapper # (

    //////////////////////////////////////
    //  Add here IP-related parameters  //
    //////////////////////////////////////

    // MBUS parameters
    parameter MBUS_ADDR_WIDTH = 32,
    parameter MBUS_DATA_WIDTH = 32,
    parameter MBUS_ID_WIDTH   = 4,
    // HBUS parameters
    parameter HBUS_DATA_WIDTH = 512,
    parameter HBUS_ADDR_WIDTH = 32,
    parameter HBUS_ID_WIDTH   = 4


) (

    ///////////////////////////////////
    //  Add here IP-related signals  //
    ///////////////////////////////////

    input  logic        clk_i,
    input  logic        rst_ni,
	output logic        interrupt_o,

    ////////////////////////////
    //  Bus Array Interfaces  //
    ////////////////////////////

    // AXI Master Interfaces
    `DEFINE_AXI_MASTER_PORTS(gmem0, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),
    `DEFINE_AXI_MASTER_PORTS(gmem1, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),
    `DEFINE_AXI_MASTER_PORTS(gmem2, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),

    // AXI Slave Interfaces
    `DEFINE_AXILITE_SLAVE_PORTS(control, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH)

);

    // HLS top
    krnl_conv_opt3 krnl_conv_opt3_u (
        .ap_clk     ( clk_i       ),
        .ap_rst_n   ( rst_ni      ),
        .interrupt  ( interrupt_o ),
        // AXI-lite slave
        .s_axi_control_AWVALID  ( control_axilite_awvalid ),
        .s_axi_control_AWREADY  ( control_axilite_awready ),
        .s_axi_control_AWADDR   ( control_axilite_awaddr  ),
        .s_axi_control_WVALID   ( control_axilite_wvalid  ),
        .s_axi_control_WREADY   ( control_axilite_wready  ),
        .s_axi_control_WDATA    ( control_axilite_wdata   ),
        .s_axi_control_WSTRB    ( control_axilite_wstrb   ),
        .s_axi_control_ARVALID  ( control_axilite_arvalid ),
        .s_axi_control_ARREADY  ( control_axilite_arready ),
        .s_axi_control_ARADDR   ( control_axilite_araddr  ),
        .s_axi_control_RVALID   ( control_axilite_rvalid  ),
        .s_axi_control_RREADY   ( control_axilite_rready  ),
        .s_axi_control_RDATA    ( control_axilite_rdata   ),
        .s_axi_control_RRESP    ( control_axilite_rresp   ),
        .s_axi_control_BVALID   ( control_axilite_bvalid  ),
        .s_axi_control_BREADY   ( control_axilite_bready  ),
        .s_axi_control_BRESP    ( control_axilite_bresp   ),
        // AXI master gmem0
        .m_axi_gmem0_AWVALID    ( gmem0_axi_awvalid       ),
        .m_axi_gmem0_AWREADY    ( gmem0_axi_awready       ),
        .m_axi_gmem0_AWADDR     ( gmem0_axi_awaddr        ),
        .m_axi_gmem0_AWID       ( gmem0_axi_awid          ),
        .m_axi_gmem0_AWLEN      ( gmem0_axi_awlen         ),
        .m_axi_gmem0_AWSIZE     ( gmem0_axi_awsize        ),
        .m_axi_gmem0_AWBURST    ( gmem0_axi_awburst       ),
        .m_axi_gmem0_AWLOCK     ( gmem0_axi_awlock        ),
        .m_axi_gmem0_AWCACHE    ( gmem0_axi_awcache       ),
        .m_axi_gmem0_AWPROT     ( gmem0_axi_awprot        ),
        .m_axi_gmem0_AWQOS      ( gmem0_axi_awqos         ),
        .m_axi_gmem0_AWREGION   ( gmem0_axi_awregion      ),
        .m_axi_gmem0_AWUSER     ( gmem0_axi_awuser        ),
        .m_axi_gmem0_WVALID     ( gmem0_axi_wvalid        ),
        .m_axi_gmem0_WREADY     ( gmem0_axi_wready        ),
        .m_axi_gmem0_WDATA      ( gmem0_axi_wdata         ),
        .m_axi_gmem0_WSTRB      ( gmem0_axi_wstrb         ),
        .m_axi_gmem0_WLAST      ( gmem0_axi_wlast         ),
        .m_axi_gmem0_WID        ( gmem0_axi_wid           ),
        .m_axi_gmem0_WUSER      ( gmem0_axi_wuser         ),
        .m_axi_gmem0_ARVALID    ( gmem0_axi_arvalid       ),
        .m_axi_gmem0_ARREADY    ( gmem0_axi_arready       ),
        .m_axi_gmem0_ARADDR     ( gmem0_axi_araddr        ),
        .m_axi_gmem0_ARID       ( gmem0_axi_arid          ),
        .m_axi_gmem0_ARLEN      ( gmem0_axi_arlen         ),
        .m_axi_gmem0_ARSIZE     ( gmem0_axi_arsize        ),
        .m_axi_gmem0_ARBURST    ( gmem0_axi_arburst       ),
        .m_axi_gmem0_ARLOCK     ( gmem0_axi_arlock        ),
        .m_axi_gmem0_ARCACHE    ( gmem0_axi_arcache       ),
        .m_axi_gmem0_ARPROT     ( gmem0_axi_arprot        ),
        .m_axi_gmem0_ARQOS      ( gmem0_axi_arqos         ),
        .m_axi_gmem0_ARREGION   ( gmem0_axi_arregion      ),
        .m_axi_gmem0_ARUSER     ( gmem0_axi_aruser        ),
        .m_axi_gmem0_RVALID     ( gmem0_axi_rvalid        ),
        .m_axi_gmem0_RREADY     ( gmem0_axi_rready        ),
        .m_axi_gmem0_RDATA      ( gmem0_axi_rdata         ),
        .m_axi_gmem0_RLAST      ( gmem0_axi_rlast         ),
        .m_axi_gmem0_RID        ( gmem0_axi_rid           ),
        .m_axi_gmem0_RUSER      ( gmem0_axi_ruser         ),
        .m_axi_gmem0_RRESP      ( gmem0_axi_rresp         ),
        .m_axi_gmem0_BVALID     ( gmem0_axi_bvalid        ),
        .m_axi_gmem0_BREADY     ( gmem0_axi_bready        ),
        .m_axi_gmem0_BRESP      ( gmem0_axi_bresp         ),
        .m_axi_gmem0_BID        ( gmem0_axi_bid           ),
        .m_axi_gmem0_BUSER      ( gmem0_axi_buser         ),
        // AXI master gmem1
        .m_axi_gmem1_AWVALID    ( gmem1_axi_awvalid       ),
        .m_axi_gmem1_AWREADY    ( gmem1_axi_awready       ),
        .m_axi_gmem1_AWADDR     ( gmem1_axi_awaddr        ),
        .m_axi_gmem1_AWID       ( gmem1_axi_awid          ),
        .m_axi_gmem1_AWLEN      ( gmem1_axi_awlen         ),
        .m_axi_gmem1_AWSIZE     ( gmem1_axi_awsize        ),
        .m_axi_gmem1_AWBURST    ( gmem1_axi_awburst       ),
        .m_axi_gmem1_AWLOCK     ( gmem1_axi_awlock        ),
        .m_axi_gmem1_AWCACHE    ( gmem1_axi_awcache       ),
        .m_axi_gmem1_AWPROT     ( gmem1_axi_awprot        ),
        .m_axi_gmem1_AWQOS      ( gmem1_axi_awqos         ),
        .m_axi_gmem1_AWREGION   ( gmem1_axi_awregion      ),
        .m_axi_gmem1_AWUSER     ( gmem1_axi_awuser        ),
        .m_axi_gmem1_WVALID     ( gmem1_axi_wvalid        ),
        .m_axi_gmem1_WREADY     ( gmem1_axi_wready        ),
        .m_axi_gmem1_WDATA      ( gmem1_axi_wdata         ),
        .m_axi_gmem1_WSTRB      ( gmem1_axi_wstrb         ),
        .m_axi_gmem1_WLAST      ( gmem1_axi_wlast         ),
        .m_axi_gmem1_WID        ( gmem1_axi_wid           ),
        .m_axi_gmem1_WUSER      ( gmem1_axi_wuser         ),
        .m_axi_gmem1_ARVALID    ( gmem1_axi_arvalid       ),
        .m_axi_gmem1_ARREADY    ( gmem1_axi_arready       ),
        .m_axi_gmem1_ARADDR     ( gmem1_axi_araddr        ),
        .m_axi_gmem1_ARID       ( gmem1_axi_arid          ),
        .m_axi_gmem1_ARLEN      ( gmem1_axi_arlen         ),
        .m_axi_gmem1_ARSIZE     ( gmem1_axi_arsize        ),
        .m_axi_gmem1_ARBURST    ( gmem1_axi_arburst       ),
        .m_axi_gmem1_ARLOCK     ( gmem1_axi_arlock        ),
        .m_axi_gmem1_ARCACHE    ( gmem1_axi_arcache       ),
        .m_axi_gmem1_ARPROT     ( gmem1_axi_arprot        ),
        .m_axi_gmem1_ARQOS      ( gmem1_axi_arqos         ),
        .m_axi_gmem1_ARREGION   ( gmem1_axi_arregion      ),
        .m_axi_gmem1_ARUSER     ( gmem1_axi_aruser        ),
        .m_axi_gmem1_RVALID     ( gmem1_axi_rvalid        ),
        .m_axi_gmem1_RREADY     ( gmem1_axi_rready        ),
        .m_axi_gmem1_RDATA      ( gmem1_axi_rdata         ),
        .m_axi_gmem1_RLAST      ( gmem1_axi_rlast         ),
        .m_axi_gmem1_RID        ( gmem1_axi_rid           ),
        .m_axi_gmem1_RUSER      ( gmem1_axi_ruser         ),
        .m_axi_gmem1_RRESP      ( gmem1_axi_rresp         ),
        .m_axi_gmem1_BVALID     ( gmem1_axi_bvalid        ),
        .m_axi_gmem1_BREADY     ( gmem1_axi_bready        ),
        .m_axi_gmem1_BRESP      ( gmem1_axi_bresp         ),
        .m_axi_gmem1_BID        ( gmem1_axi_bid           ),
        .m_axi_gmem1_BUSER      ( gmem1_axi_buser         ),
        // AXI master gmem2
        .m_axi_gmem2_AWVALID    ( gmem2_axi_awvalid       ),
        .m_axi_gmem2_AWREADY    ( gmem2_axi_awready       ),
        .m_axi_gmem2_AWADDR     ( gmem2_axi_awaddr        ),
        .m_axi_gmem2_AWID       ( gmem2_axi_awid          ),
        .m_axi_gmem2_AWLEN      ( gmem2_axi_awlen         ),
        .m_axi_gmem2_AWSIZE     ( gmem2_axi_awsize        ),
        .m_axi_gmem2_AWBURST    ( gmem2_axi_awburst       ),
        .m_axi_gmem2_AWLOCK     ( gmem2_axi_awlock        ),
        .m_axi_gmem2_AWCACHE    ( gmem2_axi_awcache       ),
        .m_axi_gmem2_AWPROT     ( gmem2_axi_awprot        ),
        .m_axi_gmem2_AWQOS      ( gmem2_axi_awqos         ),
        .m_axi_gmem2_AWREGION   ( gmem2_axi_awregion      ),
        .m_axi_gmem2_AWUSER     ( gmem2_axi_awuser        ),
        .m_axi_gmem2_WVALID     ( gmem2_axi_wvalid        ),
        .m_axi_gmem2_WREADY     ( gmem2_axi_wready        ),
        .m_axi_gmem2_WDATA      ( gmem2_axi_wdata         ),
        .m_axi_gmem2_WSTRB      ( gmem2_axi_wstrb         ),
        .m_axi_gmem2_WLAST      ( gmem2_axi_wlast         ),
        .m_axi_gmem2_WID        ( gmem2_axi_wid           ),
        .m_axi_gmem2_WUSER      ( gmem2_axi_wuser         ),
        .m_axi_gmem2_ARVALID    ( gmem2_axi_arvalid       ),
        .m_axi_gmem2_ARREADY    ( gmem2_axi_arready       ),
        .m_axi_gmem2_ARADDR     ( gmem2_axi_araddr        ),
        .m_axi_gmem2_ARID       ( gmem2_axi_arid          ),
        .m_axi_gmem2_ARLEN      ( gmem2_axi_arlen         ),
        .m_axi_gmem2_ARSIZE     ( gmem2_axi_arsize        ),
        .m_axi_gmem2_ARBURST    ( gmem2_axi_arburst       ),
        .m_axi_gmem2_ARLOCK     ( gmem2_axi_arlock        ),
        .m_axi_gmem2_ARCACHE    ( gmem2_axi_arcache       ),
        .m_axi_gmem2_ARPROT     ( gmem2_axi_arprot        ),
        .m_axi_gmem2_ARQOS      ( gmem2_axi_arqos         ),
        .m_axi_gmem2_ARREGION   ( gmem2_axi_arregion      ),
        .m_axi_gmem2_ARUSER     ( gmem2_axi_aruser        ),
        .m_axi_gmem2_RVALID     ( gmem2_axi_rvalid        ),
        .m_axi_gmem2_RREADY     ( gmem2_axi_rready        ),
        .m_axi_gmem2_RDATA      ( gmem2_axi_rdata         ),
        .m_axi_gmem2_RLAST      ( gmem2_axi_rlast         ),
        .m_axi_gmem2_RID        ( gmem2_axi_rid           ),
        .m_axi_gmem2_RUSER      ( gmem2_axi_ruser         ),
        .m_axi_gmem2_RRESP      ( gmem2_axi_rresp         ),
        .m_axi_gmem2_BVALID     ( gmem2_axi_bvalid        ),
        .m_axi_gmem2_BREADY     ( gmem2_axi_bready        ),
        .m_axi_gmem2_BRESP      ( gmem2_axi_bresp         ),
        .m_axi_gmem2_BID        ( gmem2_axi_bid           ),
        .m_axi_gmem2_BUSER      ( gmem2_axi_buser         )
    );

endmodule : custom_top_wrapper
