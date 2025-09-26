// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Author: Valerio Di Domenico <valerio.didomenico@unina.it>
// Description: This module is a wrapper for a xlnx_clock_converter.
//              It either instantiates a 32 or 64 or 512 bits clock converter

`include "uninasoc_axi.svh"

module axi_clock_converter_wrapper # (
    parameter int unsigned    LOCAL_DATA_WIDTH  = 32,
    parameter int unsigned    LOCAL_ADDR_WIDTH  = 32,
    parameter int unsigned    LOCAL_ID_WIDTH    = 2
    ) (

    // Master Interface
    input logic m_axi_aclk,
    input logic m_axi_aresetn,

    `DEFINE_AXI_MASTER_PORTS(m, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH),

    // Slave Interface
    input logic s_axi_aclk,
    input logic s_axi_aresetn,

    `DEFINE_AXI_SLAVE_PORTS(s, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

);

    generate
        case (LOCAL_DATA_WIDTH)

            32: begin : gen_axi_32_clock_conv
                xlnx_axi_d32_clock_converter axi_clk_conv_u (

                .s_axi_aclk     ( s_axi_aclk     ),
                .s_axi_aresetn  ( s_axi_aresetn  ),

                .m_axi_aclk     ( m_axi_aclk     ),
                .m_axi_aresetn  ( m_axi_aresetn  ),

                .s_axi_awid     ( s_axi_awid     ),
                .s_axi_awaddr   ( s_axi_awaddr   ),
                .s_axi_awlen    ( s_axi_awlen    ),
                .s_axi_awsize   ( s_axi_awsize   ),
                .s_axi_awburst  ( s_axi_awburst  ),
                .s_axi_awlock   ( s_axi_awlock   ),
                .s_axi_awcache  ( s_axi_awcache  ),
                .s_axi_awprot   ( s_axi_awprot   ),
                .s_axi_awqos    ( s_axi_awqos    ),
                .s_axi_awvalid  ( s_axi_awvalid  ),
                .s_axi_awready  ( s_axi_awready  ),
                .s_axi_awregion ( s_axi_awregion ),
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
                .s_axi_arlock   ( s_axi_arlock   ),
                .s_axi_arregion ( s_axi_arregion ),
                .s_axi_arcache  ( s_axi_arcache  ),
                .s_axi_arprot   ( s_axi_arprot   ),
                .s_axi_arqos    ( s_axi_arqos    ),
                .s_axi_arvalid  ( s_axi_arvalid  ),
                .s_axi_arready  ( s_axi_arready  ),
                .s_axi_rid      ( s_axi_rid      ),
                .s_axi_rdata    ( s_axi_rdata    ),
                .s_axi_rresp    ( s_axi_rresp    ),
                .s_axi_rlast    ( s_axi_rlast    ),
                .s_axi_rvalid   ( s_axi_rvalid   ),
                .s_axi_rready   ( s_axi_rready   ),

                .m_axi_awid     ( m_axi_awid     ),
                .m_axi_awaddr   ( m_axi_awaddr   ),
                .m_axi_awlen    ( m_axi_awlen    ),
                .m_axi_awsize   ( m_axi_awsize   ),
                .m_axi_awburst  ( m_axi_awburst  ),
                .m_axi_awlock   ( m_axi_awlock   ),
                .m_axi_awcache  ( m_axi_awcache  ),
                .m_axi_awprot   ( m_axi_awprot   ),
                .m_axi_awregion ( m_axi_awregion ),
                .m_axi_awqos    ( m_axi_awqos    ),
                .m_axi_awvalid  ( m_axi_awvalid  ),
                .m_axi_awready  ( m_axi_awready  ),
                .m_axi_wdata    ( m_axi_wdata    ),
                .m_axi_wstrb    ( m_axi_wstrb    ),
                .m_axi_wlast    ( m_axi_wlast    ),
                .m_axi_wvalid   ( m_axi_wvalid   ),
                .m_axi_wready   ( m_axi_wready   ),
                .m_axi_bid      ( m_axi_bid      ),
                .m_axi_bresp    ( m_axi_bresp    ),
                .m_axi_bvalid   ( m_axi_bvalid   ),
                .m_axi_bready   ( m_axi_bready   ),
                .m_axi_arid     ( m_axi_arid     ),
                .m_axi_araddr   ( m_axi_araddr   ),
                .m_axi_arlen    ( m_axi_arlen    ),
                .m_axi_arsize   ( m_axi_arsize   ),
                .m_axi_arburst  ( m_axi_arburst  ),
                .m_axi_arlock   ( m_axi_arlock   ),
                .m_axi_arcache  ( m_axi_arcache  ),
                .m_axi_arprot   ( m_axi_arprot   ),
                .m_axi_arregion ( m_axi_arregion ),
                .m_axi_arqos    ( m_axi_arqos    ),
                .m_axi_arvalid  ( m_axi_arvalid  ),
                .m_axi_arready  ( m_axi_arready  ),
                .m_axi_rid      ( m_axi_rid      ),
                .m_axi_rdata    ( m_axi_rdata    ),
                .m_axi_rresp    ( m_axi_rresp    ),
                .m_axi_rlast    ( m_axi_rlast    ),
                .m_axi_rvalid   ( m_axi_rvalid   ),
                .m_axi_rready   ( m_axi_rready   )
            );
            end

            64: begin : gen_axi_64_clock_conv
                xlnx_axi_d64_clock_converter axi_clk_conv_u (

                .s_axi_aclk     ( s_axi_aclk     ),
                .s_axi_aresetn  ( s_axi_aresetn  ),

                .m_axi_aclk     ( m_axi_aclk     ),
                .m_axi_aresetn  ( m_axi_aresetn  ),

                .s_axi_awid     ( s_axi_awid     ),
                .s_axi_awaddr   ( s_axi_awaddr   ),
                .s_axi_awlen    ( s_axi_awlen    ),
                .s_axi_awsize   ( s_axi_awsize   ),
                .s_axi_awburst  ( s_axi_awburst  ),
                .s_axi_awlock   ( s_axi_awlock   ),
                .s_axi_awcache  ( s_axi_awcache  ),
                .s_axi_awprot   ( s_axi_awprot   ),
                .s_axi_awqos    ( s_axi_awqos    ),
                .s_axi_awvalid  ( s_axi_awvalid  ),
                .s_axi_awready  ( s_axi_awready  ),
                .s_axi_awregion ( s_axi_awregion ),
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
                .s_axi_arlock   ( s_axi_arlock   ),
                .s_axi_arregion ( s_axi_arregion ),
                .s_axi_arcache  ( s_axi_arcache  ),
                .s_axi_arprot   ( s_axi_arprot   ),
                .s_axi_arqos    ( s_axi_arqos    ),
                .s_axi_arvalid  ( s_axi_arvalid  ),
                .s_axi_arready  ( s_axi_arready  ),
                .s_axi_rid      ( s_axi_rid      ),
                .s_axi_rdata    ( s_axi_rdata    ),
                .s_axi_rresp    ( s_axi_rresp    ),
                .s_axi_rlast    ( s_axi_rlast    ),
                .s_axi_rvalid   ( s_axi_rvalid   ),
                .s_axi_rready   ( s_axi_rready   ),

                .m_axi_awid     ( m_axi_awid     ),
                .m_axi_awaddr   ( m_axi_awaddr   ),
                .m_axi_awlen    ( m_axi_awlen    ),
                .m_axi_awsize   ( m_axi_awsize   ),
                .m_axi_awburst  ( m_axi_awburst  ),
                .m_axi_awlock   ( m_axi_awlock   ),
                .m_axi_awcache  ( m_axi_awcache  ),
                .m_axi_awprot   ( m_axi_awprot   ),
                .m_axi_awregion ( m_axi_awregion ),
                .m_axi_awqos    ( m_axi_awqos    ),
                .m_axi_awvalid  ( m_axi_awvalid  ),
                .m_axi_awready  ( m_axi_awready  ),
                .m_axi_wdata    ( m_axi_wdata    ),
                .m_axi_wstrb    ( m_axi_wstrb    ),
                .m_axi_wlast    ( m_axi_wlast    ),
                .m_axi_wvalid   ( m_axi_wvalid   ),
                .m_axi_wready   ( m_axi_wready   ),
                .m_axi_bid      ( m_axi_bid      ),
                .m_axi_bresp    ( m_axi_bresp    ),
                .m_axi_bvalid   ( m_axi_bvalid   ),
                .m_axi_bready   ( m_axi_bready   ),
                .m_axi_arid     ( m_axi_arid     ),
                .m_axi_araddr   ( m_axi_araddr   ),
                .m_axi_arlen    ( m_axi_arlen    ),
                .m_axi_arsize   ( m_axi_arsize   ),
                .m_axi_arburst  ( m_axi_arburst  ),
                .m_axi_arlock   ( m_axi_arlock   ),
                .m_axi_arcache  ( m_axi_arcache  ),
                .m_axi_arprot   ( m_axi_arprot   ),
                .m_axi_arregion ( m_axi_arregion ),
                .m_axi_arqos    ( m_axi_arqos    ),
                .m_axi_arvalid  ( m_axi_arvalid  ),
                .m_axi_arready  ( m_axi_arready  ),
                .m_axi_rid      ( m_axi_rid      ),
                .m_axi_rdata    ( m_axi_rdata    ),
                .m_axi_rresp    ( m_axi_rresp    ),
                .m_axi_rlast    ( m_axi_rlast    ),
                .m_axi_rvalid   ( m_axi_rvalid   ),
                .m_axi_rready   ( m_axi_rready   )
            );
            end

            512: begin : gen_axi_512_clock_conv
                xlnx_axi_d512_clock_converter axi_clk_conv_u (

                .s_axi_aclk     ( s_axi_aclk     ),
                .s_axi_aresetn  ( s_axi_aresetn  ),

                .m_axi_aclk     ( m_axi_aclk     ),
                .m_axi_aresetn  ( m_axi_aresetn  ),

                .s_axi_awid     ( s_axi_awid     ),
                .s_axi_awaddr   ( s_axi_awaddr   ),
                .s_axi_awlen    ( s_axi_awlen    ),
                .s_axi_awsize   ( s_axi_awsize   ),
                .s_axi_awburst  ( s_axi_awburst  ),
                .s_axi_awlock   ( s_axi_awlock   ),
                .s_axi_awcache  ( s_axi_awcache  ),
                .s_axi_awprot   ( s_axi_awprot   ),
                .s_axi_awqos    ( s_axi_awqos    ),
                .s_axi_awvalid  ( s_axi_awvalid  ),
                .s_axi_awready  ( s_axi_awready  ),
                .s_axi_awregion ( s_axi_awregion ),
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
                .s_axi_arlock   ( s_axi_arlock   ),
                .s_axi_arregion ( s_axi_arregion ),
                .s_axi_arcache  ( s_axi_arcache  ),
                .s_axi_arprot   ( s_axi_arprot   ),
                .s_axi_arqos    ( s_axi_arqos    ),
                .s_axi_arvalid  ( s_axi_arvalid  ),
                .s_axi_arready  ( s_axi_arready  ),
                .s_axi_rid      ( s_axi_rid      ),
                .s_axi_rdata    ( s_axi_rdata    ),
                .s_axi_rresp    ( s_axi_rresp    ),
                .s_axi_rlast    ( s_axi_rlast    ),
                .s_axi_rvalid   ( s_axi_rvalid   ),
                .s_axi_rready   ( s_axi_rready   ),

                .m_axi_awid     ( m_axi_awid     ),
                .m_axi_awaddr   ( m_axi_awaddr   ),
                .m_axi_awlen    ( m_axi_awlen    ),
                .m_axi_awsize   ( m_axi_awsize   ),
                .m_axi_awburst  ( m_axi_awburst  ),
                .m_axi_awlock   ( m_axi_awlock   ),
                .m_axi_awcache  ( m_axi_awcache  ),
                .m_axi_awprot   ( m_axi_awprot   ),
                .m_axi_awregion ( m_axi_awregion ),
                .m_axi_awqos    ( m_axi_awqos    ),
                .m_axi_awvalid  ( m_axi_awvalid  ),
                .m_axi_awready  ( m_axi_awready  ),
                .m_axi_wdata    ( m_axi_wdata    ),
                .m_axi_wstrb    ( m_axi_wstrb    ),
                .m_axi_wlast    ( m_axi_wlast    ),
                .m_axi_wvalid   ( m_axi_wvalid   ),
                .m_axi_wready   ( m_axi_wready   ),
                .m_axi_bid      ( m_axi_bid      ),
                .m_axi_bresp    ( m_axi_bresp    ),
                .m_axi_bvalid   ( m_axi_bvalid   ),
                .m_axi_bready   ( m_axi_bready   ),
                .m_axi_arid     ( m_axi_arid     ),
                .m_axi_araddr   ( m_axi_araddr   ),
                .m_axi_arlen    ( m_axi_arlen    ),
                .m_axi_arsize   ( m_axi_arsize   ),
                .m_axi_arburst  ( m_axi_arburst  ),
                .m_axi_arlock   ( m_axi_arlock   ),
                .m_axi_arcache  ( m_axi_arcache  ),
                .m_axi_arprot   ( m_axi_arprot   ),
                .m_axi_arregion ( m_axi_arregion ),
                .m_axi_arqos    ( m_axi_arqos    ),
                .m_axi_arvalid  ( m_axi_arvalid  ),
                .m_axi_arready  ( m_axi_arready  ),
                .m_axi_rid      ( m_axi_rid      ),
                .m_axi_rdata    ( m_axi_rdata    ),
                .m_axi_rresp    ( m_axi_rresp    ),
                .m_axi_rlast    ( m_axi_rlast    ),
                .m_axi_rvalid   ( m_axi_rvalid   ),
                .m_axi_rready   ( m_axi_rready   )
            );
            end

            default: begin
                initial $error("Unsupported LOCAL_DATA_WIDTH: %0d (only 32, 64, 512 are valid)", LOCAL_DATA_WIDTH);
            end

        endcase
    endgenerate

endmodule