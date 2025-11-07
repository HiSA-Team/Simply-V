// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Description:
//      This module is a wrapper for the RISC-V PLIC hosting both the PLIC and an optional
//      Data width converter. It is required as RISC-V PLIC is a 32-bits IP by default.
//      Therefore, if the MBUS is 64-bits wide, a converter is required.

`include "uninasoc_axi.svh"

module plic_wrapper # (
    parameter int unsigned    LOCAL_DATA_WIDTH  = 32,
    parameter int unsigned    LOCAL_ADDR_WIDTH  = 32,
    parameter int unsigned    LOCAL_ID_WIDTH    = 2
) (
    // Clock and reset
    input  logic            clk_i,
    input  logic            rst_ni,

    // Interrupt Sources
    input  logic [31:0]     intr_src_i,

    // Interrupt notification to targets  (One Hart, Two Contextes (M and S))
    output logic            irq_o,

    // AXI Slave Interface
    `DEFINE_AXI_SLAVE_PORTS(s, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)
);

    // Declare internal 32-bit bus to PLIC interface
    `DECLARE_AXI_BUS(to_plic, 32, 32, LOCAL_ID_WIDTH)

    //////////////////////////
    // Data Width Converter //
    //////////////////////////

    // the PLIC is always a 32-bits peripheral,
    // therefore a dwidth converter is required if XLEN = 64
    if (LOCAL_DATA_WIDTH == 64) begin : gen_axi_32_dwidth_conv

        xlnx_axi_dwidth_64_to_32_converter axi_dwidth_conv_u (
            .s_axi_aclk     ( clk_i      ),
            .s_axi_aresetn  ( rst_ni     ),

            // Slave from clock conv
            .s_axi_awid     ( s_axi_awid    ),
            .s_axi_awaddr   ( s_axi_awaddr  ),
            .s_axi_awlen    ( s_axi_awlen   ),
            .s_axi_awsize   ( s_axi_awsize  ),
            .s_axi_awburst  ( s_axi_awburst ),
            .s_axi_awvalid  ( s_axi_awvalid ),
            .s_axi_awready  ( s_axi_awready ),
            .s_axi_wdata    ( s_axi_wdata   ),
            .s_axi_wstrb    ( s_axi_wstrb   ),
            .s_axi_wlast    ( s_axi_wlast   ),
            .s_axi_wvalid   ( s_axi_wvalid  ),
            .s_axi_wready   ( s_axi_wready  ),
            .s_axi_bid      ( s_axi_bid     ),
            .s_axi_bresp    ( s_axi_bresp   ),
            .s_axi_bvalid   ( s_axi_bvalid  ),
            .s_axi_bready   ( s_axi_bready  ),
            .s_axi_arid     ( s_axi_arid    ),
            .s_axi_araddr   ( s_axi_araddr  ),
            .s_axi_arlen    ( s_axi_arlen   ),
            .s_axi_arsize   ( s_axi_arsize  ),
            .s_axi_arburst  ( s_axi_arburst ),
            .s_axi_arvalid  ( s_axi_arvalid ),
            .s_axi_arready  ( s_axi_arready ),
            .s_axi_rid      ( s_axi_rid     ),
            .s_axi_rdata    ( s_axi_rdata   ),
            .s_axi_rresp    ( s_axi_rresp   ),
            .s_axi_rlast    ( s_axi_rlast   ),
            .s_axi_rvalid   ( s_axi_rvalid  ),
            .s_axi_rready   ( s_axi_rready  ),
            .s_axi_awlock   ( s_axi_awlock  ),
            .s_axi_awcache  ( s_axi_awcache ),
            .s_axi_awprot   ( s_axi_awprot  ),
            .s_axi_awqos    ( 0   ),
            .s_axi_awregion ( 0   ),
            .s_axi_arlock   ( s_axi_arlock  ),
            .s_axi_arcache  ( s_axi_arcache ),
            .s_axi_arprot   ( s_axi_arprot  ),
            .s_axi_arqos    ( 0   ),
            .s_axi_arregion ( 0   ),

            // Master to Protocol Converter
            .m_axi_awaddr   ( to_plic_axi_awaddr  ),
            .m_axi_awlen    ( to_plic_axi_awlen   ),
            .m_axi_awsize   ( to_plic_axi_awsize  ),
            .m_axi_awburst  ( to_plic_axi_awburst ),
            .m_axi_awlock   ( to_plic_axi_awlock  ),
            .m_axi_awcache  ( to_plic_axi_awcache ),
            .m_axi_awprot   ( to_plic_axi_awprot  ),
            .m_axi_awqos    ( to_plic_axi_awqos   ),
            .m_axi_awvalid  ( to_plic_axi_awvalid ),
            .m_axi_awready  ( to_plic_axi_awready ),
            .m_axi_wdata    ( to_plic_axi_wdata   ),
            .m_axi_wstrb    ( to_plic_axi_wstrb   ),
            .m_axi_wlast    ( to_plic_axi_wlast   ),
            .m_axi_wvalid   ( to_plic_axi_wvalid  ),
            .m_axi_wready   ( to_plic_axi_wready  ),
            .m_axi_bresp    ( to_plic_axi_bresp   ),
            .m_axi_bvalid   ( to_plic_axi_bvalid  ),
            .m_axi_bready   ( to_plic_axi_bready  ),
            .m_axi_araddr   ( to_plic_axi_araddr  ),
            .m_axi_arlen    ( to_plic_axi_arlen   ),
            .m_axi_arsize   ( to_plic_axi_arsize  ),
            .m_axi_arburst  ( to_plic_axi_arburst ),
            .m_axi_arlock   ( to_plic_axi_arlock  ),
            .m_axi_arcache  ( to_plic_axi_arcache ),
            .m_axi_arprot   ( to_plic_axi_arprot  ),
            .m_axi_arqos    ( to_plic_axi_arqos   ),
            .m_axi_arvalid  ( to_plic_axi_arvalid ),
            .m_axi_arready  ( to_plic_axi_arready ),
            .m_axi_rdata    ( to_plic_axi_rdata   ),
            .m_axi_rresp    ( to_plic_axi_rresp   ),
            .m_axi_rlast    ( to_plic_axi_rlast   ),
            .m_axi_rvalid   ( to_plic_axi_rvalid  ),
            .m_axi_rready   ( to_plic_axi_rready  )
        );

        // Since the AXI data width converter has a reordering depth of 1 it doesn't have ID in its master ports - for more details see the documentation
        assign to_plic_axi_awid = '0;
        assign to_plic_axi_arid = '0;

    end : gen_axi_32_dwidth_conv
    else begin : no_conv
        `ASSIGN_AXI_BUS (to_plic, s)
    end : no_conv

    ////////////////////////////////////////////////
    // Platform-Level Interrupt Controller (PLIC) //
    ////////////////////////////////////////////////

    custom_rv_plic custom_rv_plic_u (
        .clk_i          ( clk_i                         ), // input wire s_axi_aclk
        .rst_ni         ( rst_ni                        ), // input wire s_axi_aresetn
        // AXI4 slave port (from xbar)
        .intr_src_i     ( intr_src_i                    ), // Input interrupt lines (Sources)
        .irq_o          ( irq_o                         ), // Output Interrupts (Targets -> Socket)
        .irq_id_o       (                               ), // Unused (non standard signal)
        .msip_o         (                               ), // Unused (non standard signal)
        .s_axi_awid     ( to_plic_axi_awid         ), // input wire [1 : 0] s_axi_awid
        .s_axi_awaddr   ( to_plic_axi_awaddr       ), // input wire [25 : 0] s_axi_awaddr
        .s_axi_awlen    ( to_plic_axi_awlen        ), // input wire [7 : 0] s_axi_awlen
        .s_axi_awsize   ( to_plic_axi_awsize       ), // input wire [2 : 0] s_axi_awsize
        .s_axi_awburst  ( to_plic_axi_awburst      ), // input wire [1 : 0] s_axi_awburst
        .s_axi_awlock   ( to_plic_axi_awlock       ), // input wire [0 : 0] s_axi_awlock
        .s_axi_awcache  ( to_plic_axi_awcache      ), // input wire [3 : 0] s_axi_awcache
        .s_axi_awprot   ( to_plic_axi_awprot       ), // input wire [2 : 0] s_axi_awprot
        .s_axi_awregion ( to_plic_axi_awregion     ), // input wire [3 : 0] s_axi_awregion
        .s_axi_awqos    ( to_plic_axi_awqos        ), // input wire [3 : 0] s_axi_awqos
        .s_axi_awvalid  ( to_plic_axi_awvalid      ), // input wire s_axi_awvalid
        .s_axi_awready  ( to_plic_axi_awready      ), // output wire s_axi_awready
        .s_axi_wdata    ( to_plic_axi_wdata        ), // input wire [31 : 0] s_axi_wdata
        .s_axi_wstrb    ( to_plic_axi_wstrb        ), // input wire [3 : 0] s_axi_wstrb
        .s_axi_wlast    ( to_plic_axi_wlast        ), // input wire s_axi_wlast
        .s_axi_wvalid   ( to_plic_axi_wvalid       ), // input wire s_axi_wvalid
        .s_axi_wready   ( to_plic_axi_wready       ), // output wire s_axi_wready
        .s_axi_bid      ( to_plic_axi_bid          ), // output wire [1 : 0] s_axi_bid
        .s_axi_bresp    ( to_plic_axi_bresp        ), // output wire [1 : 0] s_axi_bresp
        .s_axi_bvalid   ( to_plic_axi_bvalid       ), // output wire s_axi_bvalid
        .s_axi_bready   ( to_plic_axi_bready       ), // input wire s_axi_bready
        .s_axi_arid     ( to_plic_axi_arid         ), // input wire [1 : 0] s_axi_arid
        .s_axi_araddr   ( to_plic_axi_araddr       ), // input wire [25 : 0] s_axi_araddr
        .s_axi_arlen    ( to_plic_axi_arlen        ), // input wire [7 : 0] s_axi_arlen
        .s_axi_arsize   ( to_plic_axi_arsize       ), // input wire [2 : 0] s_axi_arsize
        .s_axi_arburst  ( to_plic_axi_arburst      ), // input wire [1 : 0] s_axi_arburst
        .s_axi_arlock   ( to_plic_axi_arlock       ), // input wire [0 : 0] s_axi_arlock
        .s_axi_arcache  ( to_plic_axi_arcache      ), // input wire [3 : 0] s_axi_arcache
        .s_axi_arprot   ( to_plic_axi_arprot       ), // input wire [2 : 0] s_axi_arprot
        .s_axi_arregion ( to_plic_axi_arregion     ), // input wire [3 : 0] s_axi_arregion
        .s_axi_arqos    ( to_plic_axi_arqos        ), // input wire [3 : 0] s_axi_arqos
        .s_axi_arvalid  ( to_plic_axi_arvalid      ), // input wire s_axi_arvalid
        .s_axi_arready  ( to_plic_axi_arready      ), // output wire s_axi_arready
        .s_axi_rid      ( to_plic_axi_rid          ), // output wire [1 : 0] s_axi_rid
        .s_axi_rdata    ( to_plic_axi_rdata        ), // output wire [31 : 0] s_axi_rdata
        .s_axi_rresp    ( to_plic_axi_rresp        ), // output wire [1 : 0] s_axi_rresp
        .s_axi_rlast    ( to_plic_axi_rlast        ), // output wire s_axi_rlast
        .s_axi_rvalid   ( to_plic_axi_rvalid       ), // output wire s_axi_rvalid
        .s_axi_rready   ( to_plic_axi_rready       )
    );


endmodule



