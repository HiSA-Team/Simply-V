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
    // AXI master interface parameters
    // NOTE: We can keep these wide, to avoid to propagate other configurations
    localparam LOCAL_AXI_DATA_WIDTH     = 512,
    localparam LOCAL_AXI_ADDR_WIDTH     = 64,
    localparam LOCAL_AXI_ID_WIDTH       = 4,
    // AXI-lite slave interface parameters
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
    `DEFINE_AXI_MASTER_PORTS(m, LOCAL_AXI_DATA_WIDTH, LOCAL_AXI_ADDR_WIDTH, LOCAL_AXI_ID_WIDTH),

    // AXI Slave Interfaces
    `DEFINE_AXILITE_SLAVE_PORTS(s_control, LOCAL_AXILITE_DATA_WIDTH, LOCAL_AXILITE_ADDR_WIDTH, LOCAL_AXILITE_ID_WIDTH)

);

    // HLS top
    krnl_conv_hbus krnl_conv_hbus_u (
        .ap_clk     ( clk_i       ),
        .ap_rst_n   ( rst_ni      ),
        .interrupt  ( interrupt_o ),
        // AXI-lite slave
        .s_axi_control_AWVALID  ( s_control_axilite_awvalid ),
        .s_axi_control_AWREADY  ( s_control_axilite_awready ),
        .s_axi_control_AWADDR   ( s_control_axilite_awaddr  ),
        .s_axi_control_WVALID   ( s_control_axilite_wvalid  ),
        .s_axi_control_WREADY   ( s_control_axilite_wready  ),
        .s_axi_control_WDATA    ( s_control_axilite_wdata   ),
        .s_axi_control_WSTRB    ( s_control_axilite_wstrb   ),
        .s_axi_control_ARVALID  ( s_control_axilite_arvalid ),
        .s_axi_control_ARREADY  ( s_control_axilite_arready ),
        .s_axi_control_ARADDR   ( s_control_axilite_araddr  ),
        .s_axi_control_RVALID   ( s_control_axilite_rvalid  ),
        .s_axi_control_RREADY   ( s_control_axilite_rready  ),
        .s_axi_control_RDATA    ( s_control_axilite_rdata   ),
        .s_axi_control_RRESP    ( s_control_axilite_rresp   ),
        .s_axi_control_BVALID   ( s_control_axilite_bvalid  ),
        .s_axi_control_BREADY   ( s_control_axilite_bready  ),
        .s_axi_control_BRESP    ( s_control_axilite_bresp   ),
        // AXI master
        .m_axi_master_AWVALID    ( m_axi_awvalid       ),
        .m_axi_master_AWREADY    ( m_axi_awready       ),
        .m_axi_master_AWADDR     ( m_axi_awaddr        ),
        .m_axi_master_AWID       ( m_axi_awid          ),
        .m_axi_master_AWLEN      ( m_axi_awlen         ),
        .m_axi_master_AWSIZE     ( m_axi_awsize        ),
        .m_axi_master_AWBURST    ( m_axi_awburst       ),
        .m_axi_master_AWLOCK     ( m_axi_awlock        ),
        .m_axi_master_AWCACHE    ( m_axi_awcache       ),
        .m_axi_master_AWPROT     ( m_axi_awprot        ),
        .m_axi_master_AWQOS      ( m_axi_awqos         ),
        .m_axi_master_AWREGION   ( m_axi_awregion      ),
        .m_axi_master_AWUSER     ( m_axi_awuser        ),
        .m_axi_master_WVALID     ( m_axi_wvalid        ),
        .m_axi_master_WREADY     ( m_axi_wready        ),
        .m_axi_master_WDATA      ( m_axi_wdata         ),
        .m_axi_master_WSTRB      ( m_axi_wstrb         ),
        .m_axi_master_WLAST      ( m_axi_wlast         ),
        .m_axi_master_WID        ( m_axi_wid           ),
        .m_axi_master_WUSER      ( m_axi_wuser         ),
        .m_axi_master_ARVALID    ( m_axi_arvalid       ),
        .m_axi_master_ARREADY    ( m_axi_arready       ),
        .m_axi_master_ARADDR     ( m_axi_araddr        ),
        .m_axi_master_ARID       ( m_axi_arid          ),
        .m_axi_master_ARLEN      ( m_axi_arlen         ),
        .m_axi_master_ARSIZE     ( m_axi_arsize        ),
        .m_axi_master_ARBURST    ( m_axi_arburst       ),
        .m_axi_master_ARLOCK     ( m_axi_arlock        ),
        .m_axi_master_ARCACHE    ( m_axi_arcache       ),
        .m_axi_master_ARPROT     ( m_axi_arprot        ),
        .m_axi_master_ARQOS      ( m_axi_arqos         ),
        .m_axi_master_ARREGION   ( m_axi_arregion      ),
        .m_axi_master_ARUSER     ( m_axi_aruser        ),
        .m_axi_master_RVALID     ( m_axi_rvalid        ),
        .m_axi_master_RREADY     ( m_axi_rready        ),
        .m_axi_master_RDATA      ( m_axi_rdata         ),
        .m_axi_master_RLAST      ( m_axi_rlast         ),
        .m_axi_master_RID        ( m_axi_rid           ),
        .m_axi_master_RUSER      ( m_axi_ruser         ),
        .m_axi_master_RRESP      ( m_axi_rresp         ),
        .m_axi_master_BVALID     ( m_axi_bvalid        ),
        .m_axi_master_BREADY     ( m_axi_bready        ),
        .m_axi_master_BRESP      ( m_axi_bresp         ),
        .m_axi_master_BID        ( m_axi_bid           ),
        .m_axi_master_BUSER      ( m_axi_buser         )
    );

endmodule : custom_top_wrapper