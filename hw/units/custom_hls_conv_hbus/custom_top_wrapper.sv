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
    localparam LOCAL_AXI_DATA_WIDTH     = 512,
    localparam LOCAL_AXI_ADDR_WIDTH     = 32,
    localparam LOCAL_AXI_ID_WIDTH       = 4,
    localparam LOCAL_AXILITE_DATA_WIDTH = 32,
    localparam LOCAL_AXILITE_ADDR_WIDTH = 32,
    localparam LOCAL_AXILITE_ID_WIDTH   = 4
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
    `DEFINE_AXI_MASTER_PORTS(gmem0, LOCAL_AXI_DATA_WIDTH, LOCAL_AXI_ADDR_WIDTH, LOCAL_AXI_ID_WIDTH),

    // AXI Slave Interfaces
    `DEFINE_AXILITE_SLAVE_PORTS(control, LOCAL_AXILITE_DATA_WIDTH, LOCAL_AXILITE_ADDR_WIDTH, LOCAL_AXILITE_ID_WIDTH)

);

    // HLS top
    krnl_conv_hbus krnl_conv_hbus_u (
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
        // AXI master
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
        .m_axi_gmem0_BUSER      ( gmem0_axi_buser         )
    );

endmodule : custom_top_wrapper