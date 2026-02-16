// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
//      Wrapper module for the RISC-V RV32 CLINT hosting both the CLINT and an optional data width converter.

`include "simplyv_axi.svh"

module clint_wrapper # (
    parameter int unsigned    LOCAL_DATA_WIDTH  = 32,
    parameter int unsigned    LOCAL_ADDR_WIDTH  = 32,
    parameter int unsigned    LOCAL_ID_WIDTH    = 2,
    // Number of CPUs (only 1, for now)
    parameter int unsigned    CLINTCORES            = 1
) (
    // Clock and reset
    input  logic       clk_i,
    input  logic       rst_ni,

    // CLINT ports
    output logic      rtc_o,       // Output divided real-time clock

    // Interrupt outputs
    output logic [CLINTCORES-1 :0] timer_irq_o, // Timer interrupts
    output logic [CLINTCORES-1 :0] ipi_o,       // software interrupt (a.k.a inter-process-interrupt)

    // AXI Slave Interface
    `DEFINE_AXI_SLAVE_PORTS(s, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)
);

    ////////////////
    // Assertions //
    ////////////////

    // For simplicity
    initial begin : assert_properties
        assert( CLINTCORES == 1 )
            else $error("CLINTCORES = %d not supported, must be 1 for now", CLINTCORES);
    end : assert_properties

    // Declare internal 32-bit bus to PLIC interface
    `DECLARE_AXI_BUS(to_clint, 32, 32, LOCAL_ID_WIDTH)

    //////////////////////////
    // Data Width Converter //
    //////////////////////////

    if ( LOCAL_DATA_WIDTH == 64 ) begin : gen_axi_32_dwidth_conv
        // Downsizer
        xlnx_axi_dwidth_64_to_32_converter axi_dwidth_conv_u (
            .s_axi_aclk     ( clk_i      ),
            .s_axi_aresetn  ( rst_ni     ),
            // Slave from MBUS
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
            // Master to CLINT
            .m_axi_awaddr   ( to_clint_axi_awaddr   ),
            .m_axi_awlen    ( to_clint_axi_awlen    ),
            .m_axi_awsize   ( to_clint_axi_awsize   ),
            .m_axi_awburst  ( to_clint_axi_awburst  ),
            .m_axi_awlock   ( to_clint_axi_awlock   ),
            .m_axi_awcache  ( to_clint_axi_awcache  ),
            .m_axi_awprot   ( to_clint_axi_awprot   ),
            .m_axi_awqos    ( to_clint_axi_awqos    ),
            .m_axi_awvalid  ( to_clint_axi_awvalid  ),
            .m_axi_awready  ( to_clint_axi_awready  ),
            .m_axi_awregion ( to_clint_axi_awregion ),
            .m_axi_wdata    ( to_clint_axi_wdata    ),
            .m_axi_wstrb    ( to_clint_axi_wstrb    ),
            .m_axi_wlast    ( to_clint_axi_wlast    ),
            .m_axi_wvalid   ( to_clint_axi_wvalid   ),
            .m_axi_wready   ( to_clint_axi_wready   ),
            .m_axi_bresp    ( to_clint_axi_bresp    ),
            .m_axi_bvalid   ( to_clint_axi_bvalid   ),
            .m_axi_bready   ( to_clint_axi_bready   ),
            .m_axi_araddr   ( to_clint_axi_araddr   ),
            .m_axi_arlen    ( to_clint_axi_arlen    ),
            .m_axi_arsize   ( to_clint_axi_arsize   ),
            .m_axi_arburst  ( to_clint_axi_arburst  ),
            .m_axi_arlock   ( to_clint_axi_arlock   ),
            .m_axi_arcache  ( to_clint_axi_arcache  ),
            .m_axi_arprot   ( to_clint_axi_arprot   ),
            .m_axi_arqos    ( to_clint_axi_arqos    ),
            .m_axi_arvalid  ( to_clint_axi_arvalid  ),
            .m_axi_arready  ( to_clint_axi_arready  ),
            .m_axi_arregion ( to_clint_axi_arregion ),
            .m_axi_rdata    ( to_clint_axi_rdata    ),
            .m_axi_rresp    ( to_clint_axi_rresp    ),
            .m_axi_rlast    ( to_clint_axi_rlast    ),
            .m_axi_rvalid   ( to_clint_axi_rvalid   ),
            .m_axi_rready   ( to_clint_axi_rready   )
        );

        // Since the AXI data width converter has a reordering depth of 1 it doesn't have ID in its master ports - for more details see the documentation
        assign to_clint_axi_awid = '0;
        assign to_clint_axi_arid = '0;
    end : gen_axi_32_dwidth_conv
    else begin : no_conv
        `ASSIGN_AXI_BUS (to_clint, s)
    end : no_conv

    ////////////////
    // RV32 CLINT //
    ////////////////

    custom_clint clint_u (
        .clk_i          ( clk_i       ),
        .rst_ni         ( rst_ni      ),
        .rtc_o          ( rtc_o       ),
        .timer_irq_o    ( timer_irq_o ), // Timer interrupts
        .ipi_o          ( ipi_o       ), // software interrupt (a.k.a inter-process-interrupt)
        // AXI slave interface
        .s_axi_awid     ( to_clint_axi_awid     ),
        .s_axi_awaddr   ( to_clint_axi_awaddr   ),
        .s_axi_awlen    ( to_clint_axi_awlen    ),
        .s_axi_awsize   ( to_clint_axi_awsize   ),
        .s_axi_awburst  ( to_clint_axi_awburst  ),
        .s_axi_awlock   ( to_clint_axi_awlock   ),
        .s_axi_awcache  ( to_clint_axi_awcache  ),
        .s_axi_awprot   ( to_clint_axi_awprot   ),
        .s_axi_awregion ( to_clint_axi_awregion ),
        .s_axi_awqos    ( to_clint_axi_awqos    ),
        .s_axi_awvalid  ( to_clint_axi_awvalid  ),
        .s_axi_awready  ( to_clint_axi_awready  ),
        .s_axi_wdata    ( to_clint_axi_wdata    ),
        .s_axi_wstrb    ( to_clint_axi_wstrb    ),
        .s_axi_wlast    ( to_clint_axi_wlast    ),
        .s_axi_wvalid   ( to_clint_axi_wvalid   ),
        .s_axi_wready   ( to_clint_axi_wready   ),
        .s_axi_bid      ( to_clint_axi_bid      ),
        .s_axi_bresp    ( to_clint_axi_bresp    ),
        .s_axi_bvalid   ( to_clint_axi_bvalid   ),
        .s_axi_bready   ( to_clint_axi_bready   ),
        .s_axi_arid     ( to_clint_axi_arid     ),
        .s_axi_araddr   ( to_clint_axi_araddr   ),
        .s_axi_arlen    ( to_clint_axi_arlen    ),
        .s_axi_arsize   ( to_clint_axi_arsize   ),
        .s_axi_arburst  ( to_clint_axi_arburst  ),
        .s_axi_arlock   ( to_clint_axi_arlock   ),
        .s_axi_arcache  ( to_clint_axi_arcache  ),
        .s_axi_arprot   ( to_clint_axi_arprot   ),
        .s_axi_arregion ( to_clint_axi_arregion ),
        .s_axi_arqos    ( to_clint_axi_arqos    ),
        .s_axi_arvalid  ( to_clint_axi_arvalid  ),
        .s_axi_arready  ( to_clint_axi_arready  ),
        .s_axi_rid      ( to_clint_axi_rid      ),
        .s_axi_rdata    ( to_clint_axi_rdata    ),
        .s_axi_rresp    ( to_clint_axi_rresp    ),
        .s_axi_rlast    ( to_clint_axi_rlast    ),
        .s_axi_rvalid   ( to_clint_axi_rvalid   ),
        .s_axi_rready   ( to_clint_axi_rready   )
    );

endmodule : clint_wrapper



