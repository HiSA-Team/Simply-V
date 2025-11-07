// Author: Vincenzo Merola <vincenzo.merola2@unina.it>
// Description:
// This module is intended as a top-level wrapper for the code in ./rtl
// It might support either MEM protocol or AXI protocol, using the
// uninasoc_axi and uninasoc_mem svh files in hw/xilinx/rtl


// Import headers
`include "uninasoc_mem.svh"
`include "uninasoc_axi.svh"

// // AXI4 MASTER PORTS
// `define DEFINE_AXI_MASTER_PORTS_dwidth(master_name, DATA_WIDTH)          \
//     // AW channel                                     \
//     output axi_id_t     ``master_name``_axi_awid,     \
//     output axi_addr_t   ``master_name``_axi_awaddr,   \
//     output axi_len_t    ``master_name``_axi_awlen,    \
//     output axi_size_t   ``master_name``_axi_awsize,   \
//     output axi_burst_t  ``master_name``_axi_awburst,  \
//     output axi_lock_t   ``master_name``_axi_awlock,   \
//     output axi_cache_t  ``master_name``_axi_awcache,  \
//     output axi_prot_t   ``master_name``_axi_awprot,   \
//     output axi_qos_t    ``master_name``_axi_awqos,    \
//     output axi_valid_t  ``master_name``_axi_awvalid,  \
//     input  axi_ready_t  ``master_name``_axi_awready,  \
//     output axi_region_t ``master_name``_axi_awregion, \
//     // W channel                                      \
//     output logic [DATA_WIDTH-1 : 0]      ``master_name``_axi_wdata,    \
//     output logic [(DATA_WIDTH/8)-1 : 0]  ``master_name``_axi_wstrb,    \
//     output axi_last_t   ``master_name``_axi_wlast,    \
//     output axi_valid_t  ``master_name``_axi_wvalid,   \
//     input  axi_ready_t  ``master_name``_axi_wready,   \
//     // B channel                                      \
//     input  axi_id_t     ``master_name``_axi_bid,      \
//     input  axi_resp_t   ``master_name``_axi_bresp,    \
//     input  axi_valid_t  ``master_name``_axi_bvalid,   \
//     output axi_ready_t  ``master_name``_axi_bready,   \
//     // AR channel                                     \
//     output axi_addr_t   ``master_name``_axi_araddr,   \
//     output axi_len_t    ``master_name``_axi_arlen,    \
//     output axi_size_t   ``master_name``_axi_arsize,   \
//     output axi_burst_t  ``master_name``_axi_arburst,  \
//     output axi_lock_t   ``master_name``_axi_arlock,   \
//     output axi_cache_t  ``master_name``_axi_arcache,  \
//     output axi_prot_t   ``master_name``_axi_arprot,   \
//     output axi_qos_t    ``master_name``_axi_arqos,    \
//     output axi_valid_t  ``master_name``_axi_arvalid,  \
//     input  axi_ready_t  ``master_name``_axi_arready,  \
//     output axi_id_t     ``master_name``_axi_arid,     \
//     output axi_region_t ``master_name``_axi_arregion, \
//     // R channel                                      \
//     input  axi_id_t     ``master_name``_axi_rid,      \
//     input [DATA_WIDTH-1 : 0] ``master_name``_axi_rdata,    \
//     input  axi_resp_t   ``master_name``_axi_rresp,    \
//     input  axi_last_t   ``master_name``_axi_rlast,    \
//     input  axi_valid_t  ``master_name``_axi_rvalid,   \
//     output axi_ready_t  ``master_name``_axi_rready


module custom_top_wrapper # (

    //////////////////////////////////////
    //  Add here IP-related parameters  //
    //////////////////////////////////////
    localparam HBUS_AXI_DATAWIDTH = 512,
    localparam HBUS_AXI_ADDRWIDTH = 32,
    localparam HBUS_AXI_IDWIDTH   = 4, 

    localparam LOCAL_AXILITE_DATAWIDTH = 32,
    localparam LOCAL_AXILITE_ADDRWIDTH = 32,
    localparam LOCAL_AXILITE_IDWIDTH   = 4 



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
    `DEFINE_AXI_MASTER_PORTS(gmem0, HBUS_AXI_DATAWIDTH, HBUS_AXI_ADDRWIDTH, HBUS_AXI_IDWIDTH),

    // AXI Slave Interfaces
    `DEFINE_AXILITE_SLAVE_PORTS(control,LOCAL_AXILITE_DATAWIDTH, LOCAL_AXILITE_ADDRWIDTH,LOCAL_AXILITE_IDWIDTH)

);

    // HLS top
    krnl_conv_opt6 krnl_conv_opt6_u (
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
