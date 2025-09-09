// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description: CMAC wrapper, this module instanciate the CMAC to access the network through the QSFP port
//              This wrapper comprises a complete subsytem (attached to the MBUS and the HBUS) for allowing external modules (the core, an accelerator, etc.) to access network packets.
//              It is structured as in the following diagram.
//              It includes two main paths:
//                  - The CSR path (AXI Lite):
//                      - MBUS to CSR CMAC
//                      - MBUS to CSR AXI Stream FIFO
//                  - The DATA path (AXI4):
//                      - HBUS to data AXI Stream FIFO
//
//              The rationale of this subsystem is to have a module (the AXI Stream FIFO) (connected to the external world)
//              that stores (sends) network packets from (to) the CMAC.
//              However, this buffering module could be, in the future, replaced by an in-network accelerator, or a TCP/IP stack or whatever...
//              It could be connected to a DDR channel too.
//
//
//                                                                                      AXI Lite 32b
//                                                                       ____________     MBUS clk                                                   ________
//                                                                      |            |                                                              |        |
//    AXI4 XLEN    _____________   AXI4 32b   ___________  AXI Lite 32b |            |------------------------------------------------------------->|        |
//     MBUS clk   | Dwidth conv |  MBUS clk  |           |   MBUS clk   |    CMAC    |                                                              |        |
// -------------->|  (optional) |----------->| Prot conv |------------->|    XBAR    |                                                              |        | QSFP RX
//                |_____________|            |___________|              |  (axilite) |       ____________  AXI Lite 32b   ____________   AXIS RX    |        |<---------
//                                                                      |            |      |            |   CMAC clk    |            |  CMAC clk   |  CMAC  |
//                                                                      |____________|----->| Clock conv |-------------->|            |<------------|        | QSFP TX
//                                                                                          |____________|               | AXI Stream |             |        |--------->
//    AXI4 512b      ____________   AXI4 512b                                                                            |    FIFO    |  AXIS TX    |        |
//     HBUS clk     |            |  CMAC clk                                                                             |            |  CMAC clk   |        |
// ---------------->| Clock conv |-------------------------------------------------------------------------------------->|            |------------>|        |
//                  | (optional) |                                                                                       |            |             |        |
//                  |____________|                                                                                       |____________|             |________|
//                                               __________________                                                            |
//                                  MBUS clk    |                  |   CMAC clk                               interrupt        |
// <--------------------------------------------| CDC Synchronizer |<----------------------------------------------------------|
//                                              |__________________|
//
//


`include "uninasoc_axi.svh"
`include "uninasoc_qsfp.svh"

module cmac_subsystem # (
    parameter int unsigned    MBUS_DATA_WIDTH   = 32,
    parameter int unsigned    MBUS_ADDR_WIDTH   = 32,
    parameter int unsigned    MBUS_ID_WIDTH     = 2,

    parameter int unsigned    LOCAL_DATA_WIDTH  = 512,
    parameter int unsigned    LOCAL_ADDR_WIDTH  = 32,
    parameter int unsigned    LOCAL_ID_WIDTH    = 2
)(

    // QSFP clock and reset
    input logic qsfp0_156mhz_clock_pi,    // Positive edge of the clock at 156 MHz for the QSFP port 0
    input logic qsfp0_156mhz_clock_ni,    // Negative edge of the clock at 156 MHz for the QSFP port 0


    // QSFP ports
    `DEFINE_QSFP_PORTS(x),

    // QSFP0 module control
    output logic qsfp0_resetl_no,    // QSFP0 module reset (active low) must be 1
    output logic qsfp0_lpmode_no,    // QSFP0 low power mode (active low) must be 1
    output logic qsfp0_modsell_no,   // QSFP0 module select (active low) must be 0

    // AXI4 ports

    // Data clock and reset
    input logic data_clock_i,
    input logic data_reset_ni,

    // CSR clock and reset
    input logic csr_clock_i,
    input logic csr_reset_ni,

    // Output clock and reset
    output logic output_clock_o,
    output logic output_reset_no,

    // AXI4 CSR
    `DEFINE_AXI_SLAVE_PORTS(s_csr, MBUS_DATA_WIDTH, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH),

    // AXI4 DATA
    `DEFINE_AXI_SLAVE_PORTS(s_data, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH),

    // TODO: Interrupts are not supported now
    // Interrupt out from the AXI Stream FIFO
    output logic interrupt_po
);


    // QSFP0 module control
    assign qsfp0_resetl_no  = 1'b1;
    assign qsfp0_lpmode_no  = 1'b1;
    assign qsfp0_modsell_no = 1'b0;


    // CMAC output clock (322,26 MHz) and reset (Active high)
    logic cmac_output_clock_322MHz;
    logic cmac_output_reset_p;

    assign output_clock_o  = cmac_output_clock_322MHz;
    assign output_reset_no = ~cmac_output_reset_p;

    // AXI Stream FIFO interrupt signal
    logic fifo_interrupt;

    // CDC Synchronizer for AXI Stream FIFO interrupt
    xpm_cdc_array_single #(
        .DEST_SYNC_FF   ( 4              ),     // Number of sync flip-flops
        .SRC_INPUT_REG  ( 1              ),     // Input register enable
        .WIDTH          ( 1              )      // Width of data to sync
    )
    xpm_cdc_array_single_inst (
        .dest_out       ( interrupt_po             ),
        .dest_clk       ( csr_clock_i             ),     // Destination clock domain (MAIN_DOMAIN)
        .src_clk        ( cmac_output_clock_322MHz ),     // Source clock domain (PBUS_DOMAIN)
        .src_in         ( fifo_interrupt           )
    );


    ////////////////
    // AXI4 buses //
    ////////////////

    // AXI4 bus (512b) for read/write data from/to the AXIS FIFO from the clock converter (DATA FIFO)
    `DECLARE_AXI_BUS(clock_conv_to_fifo, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    // AXI4 bus from dwidth conv to prot conv (CSR PATH)
    `DECLARE_AXI_BUS(to_prot_conv_csr, 32, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)


    ////////////////////
    // AXI Lite buses //
    ////////////////////

    // AXI Lite bus from prot conv to CMAC XBAR (CSR PATH)
    `DECLARE_AXILITE_BUS(prot_conv_to_cmac_xbar, 32, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    // CMAC XBAR slaves (CSR PATH)
    `DECLARE_AXILITE_BUS_ARRAY(cmac_xbar_slaves, 3, 32, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    // From CMAC XBAR to CMAC CSR (CMAC CSR PATH)
    `DECLARE_AXILITE_BUS(cmac_xbar_to_cmac_csr, 32, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)
    // From CMAC XBAR to FIFO clock conv (FIFO CSR PATH)
    `DECLARE_AXILITE_BUS(cmac_xbar_to_fifo_clock_conv, 32, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)
    // From CMAC XBAR to MATCH-ENGINE (rules management)
    (* keep = "TRUE" *) `DECLARE_AXILITE_BUS(cmac_xbar_to_match_engine, 32, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    `CONCAT_AXILITE_SLAVES_ARRAY3(cmac_xbar_slaves, cmac_xbar_to_match_engine, cmac_xbar_to_fifo_clock_conv, cmac_xbar_to_cmac_csr)

    // From FIFO clock conv to FIFO CSR (FIFO CSR PATH)
    `DECLARE_AXILITE_BUS(clock_conv_to_fifo_csr, 32, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    //////////////////////
    // AXI Stream buses //
    //////////////////////

    // AXIS bus for data transmission from the AXIS FIFO to the CMAC
    `DECLARE_AXIS_BUS(tx_fifo_to_cmac)

    // AXIS bus for data reception from the CMAC to the AXIS FIFO
    `DECLARE_AXIS_BUS(rx_cmac_to_fifo)



    ///////////////////////////
    // Modules instantiation //
    ///////////////////////////

    // Dwidth conv (optional) from the MBUS to the prot conv (CSR PATH)
    generate
        if ( MBUS_DATA_WIDTH == 64 ) begin

            xlnx_axi_dwidth_from64_to32_converter csr_dwidth_conv_u (
                .s_axi_aclk     ( csr_clock_i       ),
                .s_axi_aresetn  ( csr_reset_ni      ),

                // Slave from MBUS
                .s_axi_awid     ( s_csr_axi_awid     ),
                .s_axi_awaddr   ( s_csr_axi_awaddr   ),
                .s_axi_awlen    ( s_csr_axi_awlen    ),
                .s_axi_awsize   ( s_csr_axi_awsize   ),
                .s_axi_awburst  ( s_csr_axi_awburst  ),
                .s_axi_awvalid  ( s_csr_axi_awvalid  ),
                .s_axi_awready  ( s_csr_axi_awready  ),
                .s_axi_wdata    ( s_csr_axi_wdata    ),
                .s_axi_wstrb    ( s_csr_axi_wstrb    ),
                .s_axi_wlast    ( s_csr_axi_wlast    ),
                .s_axi_wvalid   ( s_csr_axi_wvalid   ),
                .s_axi_wready   ( s_csr_axi_wready   ),
                .s_axi_bid      ( s_csr_axi_bid      ),
                .s_axi_bresp    ( s_csr_axi_bresp    ),
                .s_axi_bvalid   ( s_csr_axi_bvalid   ),
                .s_axi_bready   ( s_csr_axi_bready   ),
                .s_axi_arid     ( s_csr_axi_arid     ),
                .s_axi_araddr   ( s_csr_axi_araddr   ),
                .s_axi_arlen    ( s_csr_axi_arlen    ),
                .s_axi_arsize   ( s_csr_axi_arsize   ),
                .s_axi_arburst  ( s_csr_axi_arburst  ),
                .s_axi_arvalid  ( s_csr_axi_arvalid  ),
                .s_axi_arready  ( s_csr_axi_arready  ),
                .s_axi_rid      ( s_csr_axi_rid      ),
                .s_axi_rdata    ( s_csr_axi_rdata    ),
                .s_axi_rresp    ( s_csr_axi_rresp    ),
                .s_axi_rlast    ( s_csr_axi_rlast    ),
                .s_axi_rvalid   ( s_csr_axi_rvalid   ),
                .s_axi_rready   ( s_csr_axi_rready   ),
                .s_axi_awlock   ( s_csr_axi_awlock   ),
                .s_axi_awcache  ( s_csr_axi_awcache  ),
                .s_axi_awprot   ( s_csr_axi_awprot   ),
                .s_axi_awqos    ( 0                  ),
                .s_axi_awregion ( 0                  ),
                .s_axi_arlock   ( s_csr_axi_arlock   ),
                .s_axi_arcache  ( s_csr_axi_arcache  ),
                .s_axi_arprot   ( s_csr_axi_arprot   ),
                .s_axi_arqos    ( 0                  ),
                .s_axi_arregion ( 0                  ),


                // Master to prot conv CSR
                // .m_axi_awid     ( to_prot_conv_csr_axi_awid  ),
                .m_axi_awaddr   ( to_prot_conv_csr_axi_awaddr  ),
                .m_axi_awlen    ( to_prot_conv_csr_axi_awlen   ),
                .m_axi_awsize   ( to_prot_conv_csr_axi_awsize  ),
                .m_axi_awburst  ( to_prot_conv_csr_axi_awburst ),
                .m_axi_awlock   ( to_prot_conv_csr_axi_awlock  ),
                .m_axi_awcache  ( to_prot_conv_csr_axi_awcache ),
                .m_axi_awprot   ( to_prot_conv_csr_axi_awprot  ),
                .m_axi_awqos    ( to_prot_conv_csr_axi_awqos   ),
                .m_axi_awvalid  ( to_prot_conv_csr_axi_awvalid ),
                .m_axi_awready  ( to_prot_conv_csr_axi_awready ),
                .m_axi_wdata    ( to_prot_conv_csr_axi_wdata   ),
                .m_axi_wstrb    ( to_prot_conv_csr_axi_wstrb   ),
                .m_axi_wlast    ( to_prot_conv_csr_axi_wlast   ),
                .m_axi_wvalid   ( to_prot_conv_csr_axi_wvalid  ),
                .m_axi_wready   ( to_prot_conv_csr_axi_wready  ),
                // .m_axi_bid      ( to_prot_conv_csr_axi_bid   ),
                .m_axi_bresp    ( to_prot_conv_csr_axi_bresp   ),
                .m_axi_bvalid   ( to_prot_conv_csr_axi_bvalid  ),
                .m_axi_bready   ( to_prot_conv_csr_axi_bready  ),
                // .m_axi_arid     ( to_prot_conv_csr_axi_arid  ),
                .m_axi_araddr   ( to_prot_conv_csr_axi_araddr  ),
                .m_axi_arlen    ( to_prot_conv_csr_axi_arlen   ),
                .m_axi_arsize   ( to_prot_conv_csr_axi_arsize  ),
                .m_axi_arburst  ( to_prot_conv_csr_axi_arburst ),
                .m_axi_arlock   ( to_prot_conv_csr_axi_arlock  ),
                .m_axi_arcache  ( to_prot_conv_csr_axi_arcache ),
                .m_axi_arprot   ( to_prot_conv_csr_axi_arprot  ),
                .m_axi_arqos    ( to_prot_conv_csr_axi_arqos   ),
                .m_axi_arvalid  ( to_prot_conv_csr_axi_arvalid ),
                .m_axi_arready  ( to_prot_conv_csr_axi_arready ),
                // .m_axi_rid      ( to_prot_conv_csr_axi_rid   ),
                .m_axi_rdata    ( to_prot_conv_csr_axi_rdata   ),
                .m_axi_rresp    ( to_prot_conv_csr_axi_rresp   ),
                .m_axi_rlast    ( to_prot_conv_csr_axi_rlast   ),
                .m_axi_rvalid   ( to_prot_conv_csr_axi_rvalid  ),
                .m_axi_rready   ( to_prot_conv_csr_axi_rready  )
            );
        end
        else begin
            `ASSIGN_AXI_BUS(to_prot_conv_csr, s_csr)
        end

    endgenerate


    generate
        // Clock converter from HBUS to dwidth converter (DATA FIFO)
        if (`HBUS_CLOCK_FREQ_MHZ != 322) begin
            axi_clock_converter_wrapper #(
                .LOCAL_DATA_WIDTH ( LOCAL_DATA_WIDTH ),
                .LOCAL_ADDR_WIDTH ( LOCAL_ADDR_WIDTH ),
                .LOCAL_ID_WIDTH   ( LOCAL_ID_WIDTH   )

            ) fifo_clock_conv_u (
                .s_axi_aclk     ( data_clock_i        ),
                .s_axi_aresetn  ( data_reset_ni       ),

                .m_axi_aclk     ( cmac_output_clock_322MHz ),
                .m_axi_aresetn  ( ~cmac_output_reset_p     ),

                .s_axi_awid     ( s_data_axi_awid          ),
                .s_axi_awaddr   ( s_data_axi_awaddr        ),
                .s_axi_awlen    ( s_data_axi_awlen         ),
                .s_axi_awsize   ( s_data_axi_awsize        ),
                .s_axi_awburst  ( s_data_axi_awburst       ),
                .s_axi_awlock   ( s_data_axi_awlock        ),
                .s_axi_awcache  ( s_data_axi_awcache       ),
                .s_axi_awprot   ( s_data_axi_awprot        ),
                .s_axi_awqos    ( s_data_axi_awqos         ),
                .s_axi_awvalid  ( s_data_axi_awvalid       ),
                .s_axi_awready  ( s_data_axi_awready       ),
                .s_axi_awregion ( s_data_axi_awregion      ),
                .s_axi_wdata    ( s_data_axi_wdata         ),
                .s_axi_wstrb    ( s_data_axi_wstrb         ),
                .s_axi_wlast    ( s_data_axi_wlast         ),
                .s_axi_wvalid   ( s_data_axi_wvalid        ),
                .s_axi_wready   ( s_data_axi_wready        ),
                .s_axi_bid      ( s_data_axi_bid           ),
                .s_axi_bresp    ( s_data_axi_bresp         ),
                .s_axi_bvalid   ( s_data_axi_bvalid        ),
                .s_axi_bready   ( s_data_axi_bready        ),
                .s_axi_arid     ( s_data_axi_arid          ),
                .s_axi_araddr   ( s_data_axi_araddr        ),
                .s_axi_arlen    ( s_data_axi_arlen         ),
                .s_axi_arsize   ( s_data_axi_arsize        ),
                .s_axi_arburst  ( s_data_axi_arburst       ),
                .s_axi_arlock   ( s_data_axi_arlock        ),
                .s_axi_arregion ( s_data_axi_arregion      ),
                .s_axi_arcache  ( s_data_axi_arcache       ),
                .s_axi_arprot   ( s_data_axi_arprot        ),
                .s_axi_arqos    ( s_data_axi_arqos         ),
                .s_axi_arvalid  ( s_data_axi_arvalid       ),
                .s_axi_arready  ( s_data_axi_arready       ),
                .s_axi_rid      ( s_data_axi_rid           ),
                .s_axi_rdata    ( s_data_axi_rdata         ),
                .s_axi_rresp    ( s_data_axi_rresp         ),
                .s_axi_rlast    ( s_data_axi_rlast         ),
                .s_axi_rvalid   ( s_data_axi_rvalid        ),
                .s_axi_rready   ( s_data_axi_rready        ),

                .m_axi_awid     ( clock_conv_to_fifo_axi_awid      ),
                .m_axi_awaddr   ( clock_conv_to_fifo_axi_awaddr    ),
                .m_axi_awlen    ( clock_conv_to_fifo_axi_awlen     ),
                .m_axi_awsize   ( clock_conv_to_fifo_axi_awsize    ),
                .m_axi_awburst  ( clock_conv_to_fifo_axi_awburst   ),
                .m_axi_awlock   ( clock_conv_to_fifo_axi_awlock    ),
                .m_axi_awcache  ( clock_conv_to_fifo_axi_awcache   ),
                .m_axi_awprot   ( clock_conv_to_fifo_axi_awprot    ),
                .m_axi_awregion ( clock_conv_to_fifo_axi_awregion  ),
                .m_axi_awqos    ( clock_conv_to_fifo_axi_awqos     ),
                .m_axi_awvalid  ( clock_conv_to_fifo_axi_awvalid   ),
                .m_axi_awready  ( clock_conv_to_fifo_axi_awready   ),
                .m_axi_wdata    ( clock_conv_to_fifo_axi_wdata     ),
                .m_axi_wstrb    ( clock_conv_to_fifo_axi_wstrb     ),
                .m_axi_wlast    ( clock_conv_to_fifo_axi_wlast     ),
                .m_axi_wvalid   ( clock_conv_to_fifo_axi_wvalid    ),
                .m_axi_wready   ( clock_conv_to_fifo_axi_wready    ),
                .m_axi_bid      ( clock_conv_to_fifo_axi_bid       ),
                .m_axi_bresp    ( clock_conv_to_fifo_axi_bresp     ),
                .m_axi_bvalid   ( clock_conv_to_fifo_axi_bvalid    ),
                .m_axi_bready   ( clock_conv_to_fifo_axi_bready    ),
                .m_axi_arid     ( clock_conv_to_fifo_axi_arid      ),
                .m_axi_araddr   ( clock_conv_to_fifo_axi_araddr    ),
                .m_axi_arlen    ( clock_conv_to_fifo_axi_arlen     ),
                .m_axi_arsize   ( clock_conv_to_fifo_axi_arsize    ),
                .m_axi_arburst  ( clock_conv_to_fifo_axi_arburst   ),
                .m_axi_arlock   ( clock_conv_to_fifo_axi_arlock    ),
                .m_axi_arcache  ( clock_conv_to_fifo_axi_arcache   ),
                .m_axi_arprot   ( clock_conv_to_fifo_axi_arprot    ),
                .m_axi_arregion ( clock_conv_to_fifo_axi_arregion  ),
                .m_axi_arqos    ( clock_conv_to_fifo_axi_arqos     ),
                .m_axi_arvalid  ( clock_conv_to_fifo_axi_arvalid   ),
                .m_axi_arready  ( clock_conv_to_fifo_axi_arready   ),
                .m_axi_rid      ( clock_conv_to_fifo_axi_rid       ),
                .m_axi_rdata    ( clock_conv_to_fifo_axi_rdata     ),
                .m_axi_rresp    ( clock_conv_to_fifo_axi_rresp     ),
                .m_axi_rlast    ( clock_conv_to_fifo_axi_rlast     ),
                .m_axi_rvalid   ( clock_conv_to_fifo_axi_rvalid    ),
                .m_axi_rready   ( clock_conv_to_fifo_axi_rready    )
            );
        end
        else begin
            `ASSIGN_AXI_BUS(clock_conv_to_fifo, s_data)
        end



    endgenerate

    // AXI4 to AXI Lite prot conv (from dwidth converter to CMAC XBAR CSR PATH)
    xlnx_axi4_to_axilite_d32_converter axi4_to_axilite_d32_converter_to_xbar_u (
        .aclk           ( csr_clock_i                   ),
        .aresetn        ( csr_reset_ni                  ),

        // AXI4 slave port (from dwidth converter)
        .s_axi_awid     ( to_prot_conv_csr_axi_awid      ),
        .s_axi_awaddr   ( to_prot_conv_csr_axi_awaddr    ),
        .s_axi_awlen    ( to_prot_conv_csr_axi_awlen     ),
        .s_axi_awsize   ( to_prot_conv_csr_axi_awsize    ),
        .s_axi_awburst  ( to_prot_conv_csr_axi_awburst   ),
        .s_axi_awlock   ( to_prot_conv_csr_axi_awlock    ),
        .s_axi_awcache  ( to_prot_conv_csr_axi_awcache   ),
        .s_axi_awprot   ( to_prot_conv_csr_axi_awprot    ),
        .s_axi_awregion ( to_prot_conv_csr_axi_awregion  ),
        .s_axi_awqos    ( to_prot_conv_csr_axi_awqos     ),
        .s_axi_awvalid  ( to_prot_conv_csr_axi_awvalid   ),
        .s_axi_awready  ( to_prot_conv_csr_axi_awready   ),
        .s_axi_wdata    ( to_prot_conv_csr_axi_wdata     ),
        .s_axi_wstrb    ( to_prot_conv_csr_axi_wstrb     ),
        .s_axi_wlast    ( to_prot_conv_csr_axi_wlast     ),
        .s_axi_wvalid   ( to_prot_conv_csr_axi_wvalid    ),
        .s_axi_wready   ( to_prot_conv_csr_axi_wready    ),
        .s_axi_bid      ( to_prot_conv_csr_axi_bid       ),
        .s_axi_bresp    ( to_prot_conv_csr_axi_bresp     ),
        .s_axi_bvalid   ( to_prot_conv_csr_axi_bvalid    ),
        .s_axi_bready   ( to_prot_conv_csr_axi_bready    ),
        .s_axi_arid     ( to_prot_conv_csr_axi_arid      ),
        .s_axi_araddr   ( to_prot_conv_csr_axi_araddr    ),
        .s_axi_arlen    ( to_prot_conv_csr_axi_arlen     ),
        .s_axi_arsize   ( to_prot_conv_csr_axi_arsize    ),
        .s_axi_arburst  ( to_prot_conv_csr_axi_arburst   ),
        .s_axi_arlock   ( to_prot_conv_csr_axi_arlock    ),
        .s_axi_arcache  ( to_prot_conv_csr_axi_arcache   ),
        .s_axi_arprot   ( to_prot_conv_csr_axi_arprot    ),
        .s_axi_arregion ( to_prot_conv_csr_axi_arregion  ),
        .s_axi_arqos    ( to_prot_conv_csr_axi_arqos     ),
        .s_axi_arvalid  ( to_prot_conv_csr_axi_arvalid   ),
        .s_axi_arready  ( to_prot_conv_csr_axi_arready   ),
        .s_axi_rid      ( to_prot_conv_csr_axi_rid       ),
        .s_axi_rdata    ( to_prot_conv_csr_axi_rdata     ),
        .s_axi_rresp    ( to_prot_conv_csr_axi_rresp     ),
        .s_axi_rlast    ( to_prot_conv_csr_axi_rlast     ),
        .s_axi_rvalid   ( to_prot_conv_csr_axi_rvalid    ),
        .s_axi_rready   ( to_prot_conv_csr_axi_rready    ),

        // Master port (to AXI Lite XBAR CSR PATH)
        .m_axi_awaddr   ( prot_conv_to_cmac_xbar_axilite_awaddr  ),
        .m_axi_awprot   ( prot_conv_to_cmac_xbar_axilite_awprot  ),
        .m_axi_awvalid  ( prot_conv_to_cmac_xbar_axilite_awvalid ),
        .m_axi_awready  ( prot_conv_to_cmac_xbar_axilite_awready ),
        .m_axi_wdata    ( prot_conv_to_cmac_xbar_axilite_wdata   ),
        .m_axi_wstrb    ( prot_conv_to_cmac_xbar_axilite_wstrb   ),
        .m_axi_wvalid   ( prot_conv_to_cmac_xbar_axilite_wvalid  ),
        .m_axi_wready   ( prot_conv_to_cmac_xbar_axilite_wready  ),
        .m_axi_bresp    ( prot_conv_to_cmac_xbar_axilite_bresp   ),
        .m_axi_bvalid   ( prot_conv_to_cmac_xbar_axilite_bvalid  ),
        .m_axi_bready   ( prot_conv_to_cmac_xbar_axilite_bready  ),
        .m_axi_araddr   ( prot_conv_to_cmac_xbar_axilite_araddr  ),
        .m_axi_arprot   ( prot_conv_to_cmac_xbar_axilite_arprot  ),
        .m_axi_arvalid  ( prot_conv_to_cmac_xbar_axilite_arvalid ),
        .m_axi_arready  ( prot_conv_to_cmac_xbar_axilite_arready ),
        .m_axi_rdata    ( prot_conv_to_cmac_xbar_axilite_rdata   ),
        .m_axi_rresp    ( prot_conv_to_cmac_xbar_axilite_rresp   ),
        .m_axi_rvalid   ( prot_conv_to_cmac_xbar_axilite_rvalid  ),
        .m_axi_rready   ( prot_conv_to_cmac_xbar_axilite_rready  )
    );

    xlnx_cmac_xbar cmac_xbar_u (
        .aclk           ( csr_clock_i  ),
        .aresetn        ( csr_reset_ni ),

        .s_axi_awaddr   ( prot_conv_to_cmac_xbar_axilite_awaddr   ),
        .s_axi_awprot   ( prot_conv_to_cmac_xbar_axilite_awprot   ),
        .s_axi_awvalid  ( prot_conv_to_cmac_xbar_axilite_awvalid  ),
        .s_axi_awready  ( prot_conv_to_cmac_xbar_axilite_awready  ),
        .s_axi_wdata    ( prot_conv_to_cmac_xbar_axilite_wdata    ),
        .s_axi_wstrb    ( prot_conv_to_cmac_xbar_axilite_wstrb    ),
        .s_axi_wvalid   ( prot_conv_to_cmac_xbar_axilite_wvalid   ),
        .s_axi_wready   ( prot_conv_to_cmac_xbar_axilite_wready   ),
        .s_axi_bresp    ( prot_conv_to_cmac_xbar_axilite_bresp    ),
        .s_axi_bvalid   ( prot_conv_to_cmac_xbar_axilite_bvalid   ),
        .s_axi_bready   ( prot_conv_to_cmac_xbar_axilite_bready   ),
        .s_axi_araddr   ( prot_conv_to_cmac_xbar_axilite_araddr   ),
        .s_axi_arprot   ( prot_conv_to_cmac_xbar_axilite_arprot   ),
        .s_axi_arvalid  ( prot_conv_to_cmac_xbar_axilite_arvalid  ),
        .s_axi_arready  ( prot_conv_to_cmac_xbar_axilite_arready  ),
        .s_axi_rdata    ( prot_conv_to_cmac_xbar_axilite_rdata    ),
        .s_axi_rresp    ( prot_conv_to_cmac_xbar_axilite_rresp    ),
        .s_axi_rvalid   ( prot_conv_to_cmac_xbar_axilite_rvalid   ),
        .s_axi_rready   ( prot_conv_to_cmac_xbar_axilite_rready   ),

        .m_axi_awaddr   ( cmac_xbar_slaves_axilite_awaddr    ),
        .m_axi_awprot   ( cmac_xbar_slaves_axilite_awprot    ),
        .m_axi_awvalid  ( cmac_xbar_slaves_axilite_awvalid   ),
        .m_axi_awready  ( cmac_xbar_slaves_axilite_awready   ),
        .m_axi_wdata    ( cmac_xbar_slaves_axilite_wdata     ),
        .m_axi_wstrb    ( cmac_xbar_slaves_axilite_wstrb     ),
        .m_axi_wvalid   ( cmac_xbar_slaves_axilite_wvalid    ),
        .m_axi_wready   ( cmac_xbar_slaves_axilite_wready    ),
        .m_axi_bresp    ( cmac_xbar_slaves_axilite_bresp     ),
        .m_axi_bvalid   ( cmac_xbar_slaves_axilite_bvalid    ),
        .m_axi_bready   ( cmac_xbar_slaves_axilite_bready    ),
        .m_axi_araddr   ( cmac_xbar_slaves_axilite_araddr    ),
        .m_axi_arprot   ( cmac_xbar_slaves_axilite_arprot    ),
        .m_axi_arvalid  ( cmac_xbar_slaves_axilite_arvalid   ),
        .m_axi_arready  ( cmac_xbar_slaves_axilite_arready   ),
        .m_axi_rdata    ( cmac_xbar_slaves_axilite_rdata     ),
        .m_axi_rresp    ( cmac_xbar_slaves_axilite_rresp     ),
        .m_axi_rvalid   ( cmac_xbar_slaves_axilite_rvalid    ),
        .m_axi_rready   ( cmac_xbar_slaves_axilite_rready    )

    );

    xlnx_axilite_d32_clock_converter cmac_xbar_to_fifo_csr_clock_conv_u (
        .s_axi_aclk     ( csr_clock_i  ),
        .s_axi_aresetn  ( csr_reset_ni ),

        .m_axi_aclk     ( cmac_output_clock_322MHz ),
        .m_axi_aresetn  ( ~cmac_output_reset_p     ),

        .s_axi_awaddr   ( cmac_xbar_to_fifo_clock_conv_axilite_awaddr   ),
        .s_axi_awprot   ( cmac_xbar_to_fifo_clock_conv_axilite_awprot   ),
        .s_axi_awvalid  ( cmac_xbar_to_fifo_clock_conv_axilite_awvalid  ),
        .s_axi_awready  ( cmac_xbar_to_fifo_clock_conv_axilite_awready  ),
        .s_axi_wdata    ( cmac_xbar_to_fifo_clock_conv_axilite_wdata    ),
        .s_axi_wstrb    ( cmac_xbar_to_fifo_clock_conv_axilite_wstrb    ),
        .s_axi_wvalid   ( cmac_xbar_to_fifo_clock_conv_axilite_wvalid   ),
        .s_axi_wready   ( cmac_xbar_to_fifo_clock_conv_axilite_wready   ),
        .s_axi_bresp    ( cmac_xbar_to_fifo_clock_conv_axilite_bresp    ),
        .s_axi_bvalid   ( cmac_xbar_to_fifo_clock_conv_axilite_bvalid   ),
        .s_axi_bready   ( cmac_xbar_to_fifo_clock_conv_axilite_bready   ),
        .s_axi_araddr   ( cmac_xbar_to_fifo_clock_conv_axilite_araddr   ),
        .s_axi_arprot   ( cmac_xbar_to_fifo_clock_conv_axilite_arprot   ),
        .s_axi_arvalid  ( cmac_xbar_to_fifo_clock_conv_axilite_arvalid  ),
        .s_axi_arready  ( cmac_xbar_to_fifo_clock_conv_axilite_arready  ),
        .s_axi_rdata    ( cmac_xbar_to_fifo_clock_conv_axilite_rdata    ),
        .s_axi_rresp    ( cmac_xbar_to_fifo_clock_conv_axilite_rresp    ),
        .s_axi_rvalid   ( cmac_xbar_to_fifo_clock_conv_axilite_rvalid   ),
        .s_axi_rready   ( cmac_xbar_to_fifo_clock_conv_axilite_rready   ),

        .m_axi_awaddr   ( clock_conv_to_fifo_csr_axilite_awaddr    ),
        .m_axi_awprot   ( clock_conv_to_fifo_csr_axilite_awprot    ),
        .m_axi_awvalid  ( clock_conv_to_fifo_csr_axilite_awvalid   ),
        .m_axi_awready  ( clock_conv_to_fifo_csr_axilite_awready   ),
        .m_axi_wdata    ( clock_conv_to_fifo_csr_axilite_wdata     ),
        .m_axi_wstrb    ( clock_conv_to_fifo_csr_axilite_wstrb     ),
        .m_axi_wvalid   ( clock_conv_to_fifo_csr_axilite_wvalid    ),
        .m_axi_wready   ( clock_conv_to_fifo_csr_axilite_wready    ),
        .m_axi_bresp    ( clock_conv_to_fifo_csr_axilite_bresp     ),
        .m_axi_bvalid   ( clock_conv_to_fifo_csr_axilite_bvalid    ),
        .m_axi_bready   ( clock_conv_to_fifo_csr_axilite_bready    ),
        .m_axi_araddr   ( clock_conv_to_fifo_csr_axilite_araddr    ),
        .m_axi_arprot   ( clock_conv_to_fifo_csr_axilite_arprot    ),
        .m_axi_arvalid  ( clock_conv_to_fifo_csr_axilite_arvalid   ),
        .m_axi_arready  ( clock_conv_to_fifo_csr_axilite_arready   ),
        .m_axi_rdata    ( clock_conv_to_fifo_csr_axilite_rdata     ),
        .m_axi_rresp    ( clock_conv_to_fifo_csr_axilite_rresp     ),
        .m_axi_rvalid   ( clock_conv_to_fifo_csr_axilite_rvalid    ),
        .m_axi_rready   ( clock_conv_to_fifo_csr_axilite_rready    )

    );


    // AXI Stream FIFO
    xlnx_axis_fifo axis_fifo_u (

        // Clock and reset
        .s_axi_aclk          ( cmac_output_clock_322MHz    ),
        .s_axi_aresetn       ( ~cmac_output_reset_p        ),

        // RX AXI Strem interface
        .axi_str_rxd_tdata   ( rx_cmac_to_fifo_axis_tdata  ),
        .axi_str_rxd_tkeep   ( rx_cmac_to_fifo_axis_tkeep  ),
        .axi_str_rxd_tlast   ( rx_cmac_to_fifo_axis_tlast  ),
        .axi_str_rxd_tready  ( rx_cmac_to_fifo_axis_tready ),
        .axi_str_rxd_tvalid  ( rx_cmac_to_fifo_axis_tvalid ),

        // TX AXI Stream interface
        .axi_str_txd_tdata   ( tx_fifo_to_cmac_axis_tdata  ),
        .axi_str_txd_tkeep   ( tx_fifo_to_cmac_axis_tkeep  ),
        .axi_str_txd_tlast   ( tx_fifo_to_cmac_axis_tlast  ),
        .axi_str_txd_tready  ( tx_fifo_to_cmac_axis_tready ),
        .axi_str_txd_tvalid  ( tx_fifo_to_cmac_axis_tvalid ),

        // AXI Lite (CSR) interface
        .s_axi_araddr        ( clock_conv_to_fifo_csr_axilite_araddr  ),     // 32 bit
        .s_axi_arready       ( clock_conv_to_fifo_csr_axilite_arready ),
        .s_axi_arvalid       ( clock_conv_to_fifo_csr_axilite_arvalid ),
        .s_axi_awaddr        ( clock_conv_to_fifo_csr_axilite_awaddr  ),     // 32 bit
        .s_axi_awready       ( clock_conv_to_fifo_csr_axilite_awready ),
        .s_axi_awvalid       ( clock_conv_to_fifo_csr_axilite_awvalid ),
        .s_axi_bready        ( clock_conv_to_fifo_csr_axilite_bready  ),
        .s_axi_bresp         ( clock_conv_to_fifo_csr_axilite_bresp   ),     // 2 bit
        .s_axi_bvalid        ( clock_conv_to_fifo_csr_axilite_bvalid  ),
        .s_axi_rdata         ( clock_conv_to_fifo_csr_axilite_rdata   ),     // 32 bit
        .s_axi_rready        ( clock_conv_to_fifo_csr_axilite_rready  ),
        .s_axi_rresp         ( clock_conv_to_fifo_csr_axilite_rresp   ),     // 2 bit
        .s_axi_rvalid        ( clock_conv_to_fifo_csr_axilite_rvalid  ),
        .s_axi_wdata         ( clock_conv_to_fifo_csr_axilite_wdata   ),     // 32 bit
        .s_axi_wready        ( clock_conv_to_fifo_csr_axilite_wready  ),
        .s_axi_wstrb         ( clock_conv_to_fifo_csr_axilite_wstrb   ),     // 4 bit
        .s_axi_wvalid        ( clock_conv_to_fifo_csr_axilite_wvalid  ),

        // AXI4 (data) interface
        .s_axi4_araddr       ( clock_conv_to_fifo_axi_araddr          ),
        .s_axi4_arburst      ( clock_conv_to_fifo_axi_arburst         ),
        .s_axi4_arcache      ( clock_conv_to_fifo_axi_arcache         ),
        .s_axi4_arid         ( clock_conv_to_fifo_axi_arid            ),
        .s_axi4_arlen        ( clock_conv_to_fifo_axi_arlen           ),
        .s_axi4_arlock       ( clock_conv_to_fifo_axi_arlock          ),
        .s_axi4_arprot       ( clock_conv_to_fifo_axi_arprot          ),
        .s_axi4_arready      ( clock_conv_to_fifo_axi_arready         ),
        .s_axi4_arsize       ( clock_conv_to_fifo_axi_arsize          ),
        .s_axi4_arvalid      ( clock_conv_to_fifo_axi_arvalid         ),
        .s_axi4_awaddr       ( clock_conv_to_fifo_axi_awaddr          ),
        .s_axi4_awburst      ( clock_conv_to_fifo_axi_awburst         ),
        .s_axi4_awcache      ( clock_conv_to_fifo_axi_awcache         ),
        .s_axi4_awid         ( clock_conv_to_fifo_axi_awid            ),
        .s_axi4_awlen        ( clock_conv_to_fifo_axi_awlen           ),
        .s_axi4_awlock       ( clock_conv_to_fifo_axi_awlock          ),
        .s_axi4_awprot       ( clock_conv_to_fifo_axi_awprot          ),
        .s_axi4_awready      ( clock_conv_to_fifo_axi_awready         ),
        .s_axi4_awsize       ( clock_conv_to_fifo_axi_awsize          ),
        .s_axi4_awvalid      ( clock_conv_to_fifo_axi_awvalid         ),
        .s_axi4_bid          ( clock_conv_to_fifo_axi_bid             ),
        .s_axi4_bready       ( clock_conv_to_fifo_axi_bready          ),
        .s_axi4_bresp        ( clock_conv_to_fifo_axi_bresp           ),
        .s_axi4_bvalid       ( clock_conv_to_fifo_axi_bvalid          ),
        .s_axi4_rdata        ( clock_conv_to_fifo_axi_rdata           ),
        .s_axi4_rid          ( clock_conv_to_fifo_axi_rid             ),
        .s_axi4_rlast        ( clock_conv_to_fifo_axi_rlast           ),
        .s_axi4_rready       ( clock_conv_to_fifo_axi_rready          ),
        .s_axi4_rresp        ( clock_conv_to_fifo_axi_rresp           ),
        .s_axi4_rvalid       ( clock_conv_to_fifo_axi_rvalid          ),
        .s_axi4_wdata        ( clock_conv_to_fifo_axi_wdata           ),
        .s_axi4_wlast        ( clock_conv_to_fifo_axi_wlast           ),
        .s_axi4_wready       ( clock_conv_to_fifo_axi_wready          ),
        .s_axi4_wstrb        ( clock_conv_to_fifo_axi_wstrb           ),
        .s_axi4_wvalid       ( clock_conv_to_fifo_axi_wvalid          ),

        // Resets out
        .mm2s_prmry_reset_out_n ( /*Not connected*/ ),
        .s2mm_prmry_reset_out_n ( /*Not connected*/ ),

        // Interrupt
        .interrupt              ( fifo_interrupt    )
    );

    //////////////////////////////////
    // SMART NIC RULE MATCH ENGINE  //
    //////////////////////////////////


    `DECLARE_AXIS_BUS(data_fifo_to_match_engine)

    (* keep = "TRUE" *)  logic [16-1:0]           tx_match_valid_out;
    (* keep = "TRUE" *)  logic [16-1:0][31:0]     tx_packet_addr_list_out;
    (* keep = "TRUE" *)  logic [$clog2(16+1)-1:0] tx_num_matches_out;
    (* keep = "TRUE" *)  logic res_mask_and;
    (* keep = "TRUE" *)  logic [16-1:0] res_mask_or;
    (* keep = "TRUE" *)  logic final_sop_match_out;

    // RULE-MATCH ENGINE
    match_engine #(
        .PKT_DATA_WIDTH              ( AXIS_TDATA_WIDTH         ),
        .PKT_KSTRB_WIDTH             ( AXIS_TKEEP_WIDTH         )
    ) match_engine_u (
        .clock_i                     ( cmac_output_clock_322MHz ),
        .reset_ni                    ( ~cmac_output_reset_p     ),

        .rules_clock_i               ( csr_clock_i              ),
        .rules_reset_ni              ( csr_reset_ni             ),

        // AXIS interface from the CMAC
        .s_axis_tdata                ( data_fifo_to_match_engine_axis_tdata  ),
        .s_axis_tkeep                ( data_fifo_to_match_engine_axis_tkeep  ),
        .s_axis_tlast                ( data_fifo_to_match_engine_axis_tlast  ),
        .s_axis_tvalid               ( data_fifo_to_match_engine_axis_tvalid ),
        .s_axis_tready               ( data_fifo_to_match_engine_axis_tready ),

        // AXI Lite interface to update rules
        .s_rules_axilite_awaddr      ( cmac_xbar_to_match_engine_axilite_awaddr   ),
        .s_rules_axilite_awprot      ( cmac_xbar_to_match_engine_axilite_awprot   ),
        .s_rules_axilite_awvalid     ( cmac_xbar_to_match_engine_axilite_awvalid  ),
        .s_rules_axilite_awready     ( cmac_xbar_to_match_engine_axilite_awready  ),
        .s_rules_axilite_wdata       ( cmac_xbar_to_match_engine_axilite_wdata    ),
        .s_rules_axilite_wstrb       ( cmac_xbar_to_match_engine_axilite_wstrb    ),
        .s_rules_axilite_wvalid      ( cmac_xbar_to_match_engine_axilite_wvalid   ),
        .s_rules_axilite_wready      ( cmac_xbar_to_match_engine_axilite_wready   ),
        .s_rules_axilite_bresp       ( cmac_xbar_to_match_engine_axilite_bresp    ),
        .s_rules_axilite_bvalid      ( cmac_xbar_to_match_engine_axilite_bvalid   ),
        .s_rules_axilite_bready      ( cmac_xbar_to_match_engine_axilite_bready   ),
        .s_rules_axilite_araddr      ( cmac_xbar_to_match_engine_axilite_araddr   ),
        .s_rules_axilite_arprot      ( cmac_xbar_to_match_engine_axilite_arprot   ),
        .s_rules_axilite_arvalid     ( cmac_xbar_to_match_engine_axilite_arvalid  ),
        .s_rules_axilite_arready     ( cmac_xbar_to_match_engine_axilite_arready  ),
        .s_rules_axilite_rdata       ( cmac_xbar_to_match_engine_axilite_rdata    ),
        .s_rules_axilite_rresp       ( cmac_xbar_to_match_engine_axilite_rresp    ),
        .s_rules_axilite_rvalid      ( cmac_xbar_to_match_engine_axilite_rvalid   ),
        .s_rules_axilite_rready      ( cmac_xbar_to_match_engine_axilite_rready   ),


        .rule_logic_mask_and_in      ( '0 ),               // Maschera per le regole che devono essere combinate in AND
        .rule_logic_mask_or_in       ( '0 ),               // Maschera per le regole che devono essere combinate in OR
        .final_match_logic_enable_in ( '0 ),               // Abilita/disabilita la logica booleana finale
        .res_mask_and                ( res_mask_and ),      // se alto la maschera di regole in and ha avuto successo
        .res_mask_or                 ( res_mask_or  ),      // viene specificate quale regole in or matcha nel pacchetto

        // Input per la logica SOP
        .sop_term_masks_in           ( '0 ),               // Matrice di maschere: sop_term_masks_in[j] definisce il j-esimo termine AND
        .sop_term_enable_in          ( '0 ),               // Abilita/disabilita ogni termine AND
        .sop_logic_enable_in         ( '0 ),               // Abilita/disabilita l'intera logica SOP
        .final_sop_match_out         ( final_sop_match_out ),      // Risultato finale della logica SOP

        .tx_match_valid_out          ( tx_match_valid_out      ),
        .tx_packet_addr_list_out     ( tx_packet_addr_list_out ),
        .tx_num_matches_out          ( tx_num_matches_out      )
    );

    // AXI-Stream data FIFO
    xlnx_axis_data_fifo axis_data_fifo (
        .s_axis_aclk              ( cmac_output_clock_322MHz    ),
        .s_axis_aresetn           ( ~cmac_output_reset_p        ),

        .s_axis_tdata             ( rx_cmac_to_fifo_axis_tdata  ),      // 512 bit
        .s_axis_tkeep             ( rx_cmac_to_fifo_axis_tkeep  ),      //  64 bit
        .s_axis_tlast             ( rx_cmac_to_fifo_axis_tlast  ),
        .s_axis_tready            (  ),
        .s_axis_tuser             ( rx_cmac_to_fifo_axis_tuser  ),
        .s_axis_tvalid            ( rx_cmac_to_fifo_axis_tvalid ),

        .m_axis_tdata             ( data_fifo_to_match_engine_axis_tdata  ),      // 512 bit
        .m_axis_tkeep             ( data_fifo_to_match_engine_axis_tkeep  ),      //  64 bit
        .m_axis_tlast             ( data_fifo_to_match_engine_axis_tlast  ),
        .m_axis_tready            ( data_fifo_to_match_engine_axis_tready ),
        .m_axis_tuser             ( data_fifo_to_match_engine_axis_tuser  ),
        .m_axis_tvalid            ( data_fifo_to_match_engine_axis_tvalid )
    );






    // CMAC
    xlnx_cmac cmac_u (


        // GT ref clock 156.25 MHz differential
        .gt_ref_clk_n              ( qsfp0_156mhz_clock_ni       ),
        .gt_ref_clk_p              ( qsfp0_156mhz_clock_pi       ),

        // GT ports (to the physical pin) 4 differential lanes for each direction (rx and tx)
        .gt_rxn_in                 ( qsfpx_rxn_i                 ),
        .gt_rxp_in                 ( qsfpx_rxp_i                 ),
        .gt_txn_out                ( qsfpx_txn_o                 ),
        .gt_txp_out                ( qsfpx_txp_o                 ),

        // AXIS TX interface
        .tx_axis_tdata             ( tx_fifo_to_cmac_axis_tdata  ),      // 512 bit
        .tx_axis_tkeep             ( tx_fifo_to_cmac_axis_tkeep  ),      //  64 bit
        .tx_axis_tlast             ( tx_fifo_to_cmac_axis_tlast  ),
        .tx_axis_tready            ( tx_fifo_to_cmac_axis_tready ),
        .tx_axis_tuser             ( tx_fifo_to_cmac_axis_tuser  ),
        .tx_axis_tvalid            ( tx_fifo_to_cmac_axis_tvalid ),

        // AXIS RX interface
        .rx_axis_tdata             ( rx_cmac_to_fifo_axis_tdata  ),      // 512 bit
        .rx_axis_tkeep             ( rx_cmac_to_fifo_axis_tkeep  ),      //  64 bit
        .rx_axis_tlast             ( rx_cmac_to_fifo_axis_tlast  ),
        .rx_axis_tuser             ( rx_cmac_to_fifo_axis_tuser  ),
        .rx_axis_tvalid            ( rx_cmac_to_fifo_axis_tvalid ),


        // AXI Lite interface ( CSR space )
        .s_axi_aclk                ( csr_clock_i                          ),
        .s_axi_sreset              ( ~csr_reset_ni                        ),     // Active high

        .s_axi_araddr              ( cmac_xbar_to_cmac_csr_axilite_araddr  ),     // 32 bit
        .s_axi_arready             ( cmac_xbar_to_cmac_csr_axilite_arready ),
        .s_axi_arvalid             ( cmac_xbar_to_cmac_csr_axilite_arvalid ),
        .s_axi_awaddr              ( cmac_xbar_to_cmac_csr_axilite_awaddr  ),     // 32 bit
        .s_axi_awready             ( cmac_xbar_to_cmac_csr_axilite_awready ),
        .s_axi_awvalid             ( cmac_xbar_to_cmac_csr_axilite_awvalid ),
        .s_axi_bready              ( cmac_xbar_to_cmac_csr_axilite_bready  ),
        .s_axi_bresp               ( cmac_xbar_to_cmac_csr_axilite_bresp   ),     // 2 bit
        .s_axi_bvalid              ( cmac_xbar_to_cmac_csr_axilite_bvalid  ),
        .s_axi_rdata               ( cmac_xbar_to_cmac_csr_axilite_rdata   ),     // 32 bit
        .s_axi_rready              ( cmac_xbar_to_cmac_csr_axilite_rready  ),
        .s_axi_rresp               ( cmac_xbar_to_cmac_csr_axilite_rresp   ),     // 2 bit
        .s_axi_rvalid              ( cmac_xbar_to_cmac_csr_axilite_rvalid  ),
        .s_axi_wdata               ( cmac_xbar_to_cmac_csr_axilite_wdata   ),     // 32 bit
        .s_axi_wready              ( cmac_xbar_to_cmac_csr_axilite_wready  ),
        .s_axi_wstrb               ( cmac_xbar_to_cmac_csr_axilite_wstrb   ),     // 4 bit
        .s_axi_wvalid              ( cmac_xbar_to_cmac_csr_axilite_wvalid  ),


        // CMAC output clocks at 322,26 MHz (these two are the same clock, let's use only txusrclk2)
        .gt_txusrclk2              ( cmac_output_clock_322MHz ),
        .gt_rxusrclk2              ( /* Not connected */      ),

        // CMAC output ref clock (this is the same clock as gt_ref_clk, but not differential)
        .gt_ref_clk_out            ( /*Not connected*/ ),

        // CMAC other output clocks (these are other 4 clocks at 322,26 MHz)
        .gt_rxrecclkout            ( /*Not connected*/ ),

        // CMAC output resets (again these are the same reset, let's use only usr_tx_reset)
        .usr_tx_reset              ( cmac_output_reset_p ),   // Active high
        .usr_rx_reset              ( /* Not connected */ ),   // Active high


        // CMAC input clocks and resets
        .init_clk                  ( csr_clock_i             ),
        .sys_reset                 ( ~csr_reset_ni           ),   // Active high

        .rx_clk                    ( cmac_output_clock_322MHz ),   // 322,26 MHz
        .core_rx_reset             ( 1'b0                     ),   // Active high
        .core_tx_reset             ( 1'b0                     ),   // Active high
        .gtwiz_reset_tx_datapath   ( 1'b0                     ),   // Active high
        .gtwiz_reset_rx_datapath   ( 1'b0                     ),   // Active high

        // DRP (Dynamic Reconfiguration Port ) interface (not needed)
        .core_drp_reset            ( 1'b0              ),   // Active high
        .drp_clk                   ( csr_clock_i      ),   // This should be the same as init_clk
        .drp_addr                  ( '0                ),   // 10 bit
        .drp_di                    ( '0                ),   // 16 bit
        .drp_en                    ( '0                ),
        .drp_we                    ( '0                ),
        .drp_do                    ( /*Not connected*/ ),   // 16 bit
        .drp_rdy                   ( /*Not connected*/ ),

        // Loopback interface (not needed for now)
        .gt_loopback_in            ( '0 ),   // 12 bit

        // TX preamble (not needed for now)
        .tx_preamblein             ( '0                ),   // 56 bit

        // RX preamble (not needed for now)
        .rx_preambleout            ( /*Not connected*/ ),   // 56 bit


        // ctl TX, control interface for tx (not needed as we are using axilite)
        .ctl_tx_send_idle          ( 1'b0 ),
        .ctl_tx_send_lfi           ( 1'b0 ),
        .ctl_tx_send_rfi           ( 1'b0 ),

        // flow control interface for tx (not needed as we are using axilite)
        .ctl_tx_pause_req          ( '0   ),  // 9 bit
        .ctl_tx_resend_pause       ( 1'b0 ),

        // stat TX, status interface for tx (not needed as we are using axilite)
        .stat_tx_bad_fcs                  ( /*Not connected*/ ),
        .stat_tx_broadcast                ( /*Not connected*/ ),
        .stat_tx_frame_error              ( /*Not connected*/ ),
        .stat_tx_local_fault              ( /*Not connected*/ ),
        .stat_tx_multicast                ( /*Not connected*/ ),
        .stat_tx_packet_64_bytes          ( /*Not connected*/ ),
        .stat_tx_packet_65_127_bytes      ( /*Not connected*/ ),
        .stat_tx_packet_128_255_bytes     ( /*Not connected*/ ),
        .stat_tx_packet_256_511_bytes     ( /*Not connected*/ ),
        .stat_tx_packet_512_1023_bytes    ( /*Not connected*/ ),
        .stat_tx_packet_1024_1518_bytes   ( /*Not connected*/ ),
        .stat_tx_packet_1519_1522_bytes   ( /*Not connected*/ ),
        .stat_tx_packet_1523_1548_bytes   ( /*Not connected*/ ),
        .stat_tx_packet_1549_2047_bytes   ( /*Not connected*/ ),
        .stat_tx_packet_2048_4095_bytes   ( /*Not connected*/ ),
        .stat_tx_packet_4096_8191_bytes   ( /*Not connected*/ ),
        .stat_tx_packet_8192_9215_bytes   ( /*Not connected*/ ),
        .stat_tx_packet_large             ( /*Not connected*/ ),
        .stat_tx_packet_small             ( /*Not connected*/ ),
        .stat_tx_total_bytes              ( /*Not connected*/ ),   //  6 bit
        .stat_tx_total_good_bytes         ( /*Not connected*/ ),   // 14 bit
        .stat_tx_total_good_packets       ( /*Not connected*/ ),
        .stat_tx_total_packets            ( /*Not connected*/ ),
        .stat_tx_unicast                  ( /*Not connected*/ ),
        .stat_tx_vlan                     ( /*Not connected*/ ),
        .stat_tx_user_pause               ( /*Not connected*/ ),
        .stat_tx_pause_valid              ( /*Not connected*/ ),   // 9 bit
        .stat_tx_pause                    ( /*Not connected*/ ),

        // stat RX, status interface for rx (not needed as we are using axilite)
        .stat_rx_aligned                  ( /*Not connected*/ ),
        .stat_rx_aligned_err              ( /*Not connected*/ ),
        .stat_rx_bad_code                 ( /*Not connected*/ ),   // 3 bit
        .stat_rx_bad_fcs                  ( /*Not connected*/ ),   // 3 bit
        .stat_rx_bad_preamble             ( /*Not connected*/ ),
        .stat_rx_bad_sfd                  ( /*Not connected*/ ),
        .stat_rx_bip_err_0                ( /*Not connected*/ ),
        .stat_rx_bip_err_1                ( /*Not connected*/ ),
        .stat_rx_bip_err_2                ( /*Not connected*/ ),
        .stat_rx_bip_err_3                ( /*Not connected*/ ),
        .stat_rx_bip_err_4                ( /*Not connected*/ ),
        .stat_rx_bip_err_5                ( /*Not connected*/ ),
        .stat_rx_bip_err_6                ( /*Not connected*/ ),
        .stat_rx_bip_err_7                ( /*Not connected*/ ),
        .stat_rx_bip_err_8                ( /*Not connected*/ ),
        .stat_rx_bip_err_9                ( /*Not connected*/ ),
        .stat_rx_bip_err_10               ( /*Not connected*/ ),
        .stat_rx_bip_err_11               ( /*Not connected*/ ),
        .stat_rx_bip_err_12               ( /*Not connected*/ ),
        .stat_rx_bip_err_13               ( /*Not connected*/ ),
        .stat_rx_bip_err_14               ( /*Not connected*/ ),
        .stat_rx_bip_err_15               ( /*Not connected*/ ),
        .stat_rx_bip_err_16               ( /*Not connected*/ ),
        .stat_rx_bip_err_17               ( /*Not connected*/ ),
        .stat_rx_bip_err_18               ( /*Not connected*/ ),
        .stat_rx_bip_err_19               ( /*Not connected*/ ),
        .stat_rx_block_lock               ( /*Not connected*/ ),   // 20 bit
        .stat_rx_broadcast                ( /*Not connected*/ ),
        .stat_rx_fragment                 ( /*Not connected*/ ),   //  3 bit
        .stat_rx_framing_err_0            ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_1            ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_2            ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_3            ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_4            ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_5            ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_6            ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_7            ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_8            ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_9            ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_10           ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_11           ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_12           ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_13           ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_14           ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_15           ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_16           ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_17           ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_18           ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_19           ( /*Not connected*/ ),   //  2 bit
        .stat_rx_framing_err_valid_0      ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_1      ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_2      ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_3      ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_4      ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_5      ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_6      ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_7      ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_8      ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_9      ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_10     ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_11     ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_12     ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_13     ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_14     ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_15     ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_16     ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_17     ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_18     ( /*Not connected*/ ),
        .stat_rx_framing_err_valid_19     ( /*Not connected*/ ),
        .stat_rx_got_signal_os            ( /*Not connected*/ ),
        .stat_rx_hi_ber                   ( /*Not connected*/ ),
        .stat_rx_inrangeerr               ( /*Not connected*/ ),
        .stat_rx_internal_local_fault     ( /*Not connected*/ ),
        .stat_rx_jabber                   ( /*Not connected*/ ),
        .stat_rx_local_fault              ( /*Not connected*/ ),
        .stat_rx_mf_err                   ( /*Not connected*/ ),    // 20 bit
        .stat_rx_mf_len_err               ( /*Not connected*/ ),    // 20 bit
        .stat_rx_mf_repeat_err            ( /*Not connected*/ ),    // 20 bit
        .stat_rx_misaligned               ( /*Not connected*/ ),
        .stat_rx_multicast                ( /*Not connected*/ ),
        .stat_rx_oversize                 ( /*Not connected*/ ),
        .stat_rx_packet_64_bytes          ( /*Not connected*/ ),
        .stat_rx_packet_65_127_bytes      ( /*Not connected*/ ),
        .stat_rx_packet_128_255_bytes     ( /*Not connected*/ ),
        .stat_rx_packet_256_511_bytes     ( /*Not connected*/ ),
        .stat_rx_packet_512_1023_bytes    ( /*Not connected*/ ),
        .stat_rx_packet_1024_1518_bytes   ( /*Not connected*/ ),
        .stat_rx_packet_1519_1522_bytes   ( /*Not connected*/ ),
        .stat_rx_packet_1523_1548_bytes   ( /*Not connected*/ ),
        .stat_rx_packet_1549_2047_bytes   ( /*Not connected*/ ),
        .stat_rx_packet_2048_4095_bytes   ( /*Not connected*/ ),
        .stat_rx_packet_4096_8191_bytes   ( /*Not connected*/ ),
        .stat_rx_packet_8192_9215_bytes   ( /*Not connected*/ ),
        .stat_rx_packet_bad_fcs           ( /*Not connected*/ ),
        .stat_rx_packet_large             ( /*Not connected*/ ),
        .stat_rx_packet_small             ( /*Not connected*/ ),   //  3 bit
        .stat_rx_pause                    ( /*Not connected*/ ),
        .stat_rx_pause_quanta0            ( /*Not connected*/ ),   // 16 bit
        .stat_rx_pause_quanta1            ( /*Not connected*/ ),   // 16 bit
        .stat_rx_pause_quanta2            ( /*Not connected*/ ),   // 16 bit
        .stat_rx_pause_quanta3            ( /*Not connected*/ ),   // 16 bit
        .stat_rx_pause_quanta4            ( /*Not connected*/ ),   // 16 bit
        .stat_rx_pause_quanta5            ( /*Not connected*/ ),   // 16 bit
        .stat_rx_pause_quanta6            ( /*Not connected*/ ),   // 16 bit
        .stat_rx_pause_quanta7            ( /*Not connected*/ ),   // 16 bit
        .stat_rx_pause_quanta8            ( /*Not connected*/ ),   // 16 bit
        .stat_rx_pause_req                ( /*Not connected*/ ),   //  9 bit
        .stat_rx_pause_valid              ( /*Not connected*/ ),   //  9 bit
        .stat_rx_user_pause               ( /*Not connected*/ ),
        .stat_rx_received_local_fault     ( /*Not connected*/ ),
        .stat_rx_remote_fault             ( /*Not connected*/ ),
        .stat_rx_status                   ( /*Not connected*/ ),
        .stat_rx_stomped_fcs              ( /*Not connected*/ ),   //  3 bit
        .stat_rx_synced                   ( /*Not connected*/ ),   // 20 bit
        .stat_rx_synced_err               ( /*Not connected*/ ),   // 20 bit
        .stat_rx_test_pattern_mismatch    ( /*Not connected*/ ),   //  3 bit
        .stat_rx_toolong                  ( /*Not connected*/ ),
        .stat_rx_total_bytes              ( /*Not connected*/ ),   //  7 bit
        .stat_rx_total_good_bytes         ( /*Not connected*/ ),   // 14 bit
        .stat_rx_total_good_packets       ( /*Not connected*/ ),
        .stat_rx_total_packets            ( /*Not connected*/ ),   //  3 bit
        .stat_rx_truncated                ( /*Not connected*/ ),
        .stat_rx_undersize                ( /*Not connected*/ ),   //  3 bit
        .stat_rx_unicast                  ( /*Not connected*/ ),
        .stat_rx_vlan                     ( /*Not connected*/ ),
        .stat_rx_pcsl_demuxed             ( /*Not connected*/ ),   // 20 bit
        .stat_rx_pcsl_number_0            ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_1            ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_2            ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_3            ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_4            ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_5            ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_6            ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_7            ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_8            ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_9            ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_10           ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_11           ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_12           ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_13           ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_14           ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_15           ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_16           ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_17           ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_18           ( /*Not connected*/ ),   //  5 bit
        .stat_rx_pcsl_number_19           ( /*Not connected*/ ),   //  5 bit


        // RS-FEC (Reed Solomon Forward Error Correction) status interface (not needed for now)
        .stat_rx_rsfec_am_lock0               ( /*Not connected*/ ),
        .stat_rx_rsfec_am_lock1               ( /*Not connected*/ ),
        .stat_rx_rsfec_am_lock2               ( /*Not connected*/ ),
        .stat_rx_rsfec_am_lock3               ( /*Not connected*/ ),
        .stat_rx_rsfec_corrected_cw_inc       ( /*Not connected*/ ),
        .stat_rx_rsfec_cw_inc                 ( /*Not connected*/ ),
        .stat_rx_rsfec_err_count0_inc         ( /*Not connected*/ ),   //  3 bit
        .stat_rx_rsfec_err_count1_inc         ( /*Not connected*/ ),   //  3 bit
        .stat_rx_rsfec_err_count2_inc         ( /*Not connected*/ ),   //  3 bit
        .stat_rx_rsfec_err_count3_inc         ( /*Not connected*/ ),   //  3 bit
        .stat_rx_rsfec_hi_ser                 ( /*Not connected*/ ),
        .stat_rx_rsfec_lane_alignment_status  ( /*Not connected*/ ),
        .stat_rx_rsfec_lane_fill_0            ( /*Not connected*/ ),   // 14 bit
        .stat_rx_rsfec_lane_fill_1            ( /*Not connected*/ ),   // 14 bit
        .stat_rx_rsfec_lane_fill_2            ( /*Not connected*/ ),   // 14 bit
        .stat_rx_rsfec_lane_fill_3            ( /*Not connected*/ ),   // 14 bit
        .stat_rx_rsfec_lane_mapping           ( /*Not connected*/ ),   //  8 bit
        .stat_rx_rsfec_uncorrected_cw_inc     ( /*Not connected*/ ),

        // RX OTN (Optical Transport Network)
        .rx_otn_bip8_0                        ( /*Not connected*/ ),   //  8 bit
        .rx_otn_bip8_1                        ( /*Not connected*/ ),   //  8 bit
        .rx_otn_bip8_2                        ( /*Not connected*/ ),   //  8 bit
        .rx_otn_bip8_3                        ( /*Not connected*/ ),   //  8 bit
        .rx_otn_bip8_4                        ( /*Not connected*/ ),   //  8 bit
        .rx_otn_data_0                        ( /*Not connected*/ ),   // 66 bit
        .rx_otn_data_1                        ( /*Not connected*/ ),   // 66 bit
        .rx_otn_data_2                        ( /*Not connected*/ ),   // 66 bit
        .rx_otn_data_3                        ( /*Not connected*/ ),   // 66 bit
        .rx_otn_data_4                        ( /*Not connected*/ ),   // 66 bit
        .rx_otn_ena                           ( /*Not connected*/ ),
        .rx_otn_lane0                         ( /*Not connected*/ ),
        .rx_otn_vlmarker                      ( /*Not connected*/ ),

        // GT power good
        .gt_powergoodout                      ( /*Not connected*/ ),

        // TX overflow and underflow errors (these are for the LBUS interface, we are using the AXIS interface, so not needed)
        .tx_ovfout                            ( /*Not connected*/ ),
        .tx_unfout                            ( /*Not connected*/ ),

        .pm_tick                              ( 1'b0 )
    );

endmodule
