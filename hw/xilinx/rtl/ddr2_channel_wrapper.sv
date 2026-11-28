// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Description: This module is a wrapper for a single Nexys A7 DDR2 channel.
//              It includes :
//                 - A System Cache with AXI exclusive access support
//                 - A 128-bit clock converter from the SoC clock to the MIG UI clock
//                 - A DDR2 (MIG) IP
//                 - AXI reset synchronization, held until calibration completes
//
//              It has the following sub-architecture:
//
//   Main Clock Domain                              DDR2 UI Clock Domain
//   DATA: 32/64 bit -> 128 bit                      DATA: 128 bit
//                 _____________            _____________            ____________
//   s_axi ------>|   System    |--------->|    Clock    |--------->|            |
//                |    Cache    |to_clk_conv| Converter  |   to_mig | DDR2 (MIG) |---> DDR2
//                |_____________|          |_____________|          |____________|
//                                                                  ADDR: 27 bit

`include "simplyv_axi.svh"
`include "simplyv_ddr2.svh"

module ddr2_channel_wrapper # (
    parameter int unsigned LOCAL_DATA_WIDTH = 32,
    parameter int unsigned LOCAL_ADDR_WIDTH = 32,
    parameter int unsigned LOCAL_ID_WIDTH   = 5
) (
    input logic clock_i,
    input logic reset_ni,
    input logic clk_200mhz_i,
    input logic sys_reset_ni,

    `DEFINE_DDR2_PORTS,

    output logic ddr_clk_o,
    output logic ddr_rst_o,
    output logic init_calib_complete_o,

    `DEFINE_AXI_SLAVE_PORTS(s, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)
);

    localparam int DDR2_DATA_WIDTH = 128;
    localparam int DDR2_ADDR_WIDTH = 27;

    logic ui_clk_sync_rst;
    logic axi_resetn_soc;
    logic axi_resetn_ui;
    logic reset_request;

    // Reset aborts in-flight traffic; reset the connected AXI masters as well.
    assign reset_request = ~reset_ni | ~sys_reset_ni |
                           ui_clk_sync_rst | ~init_calib_complete_o;
    assign ddr_rst_o = ~axi_resetn_ui;

    xpm_cdc_async_rst #(
        .DEST_SYNC_FF    ( 4 ),
        .RST_ACTIVE_HIGH ( 0 )
    ) axi_reset_soc_u (
        .src_arst  ( ~reset_request ),
        .dest_clk  ( clock_i        ),
        .dest_arst ( axi_resetn_soc )
    );

    xpm_cdc_async_rst #(
        .DEST_SYNC_FF    ( 4 ),
        .RST_ACTIVE_HIGH ( 0 )
    ) axi_reset_ui_u (
        .src_arst  ( ~reset_request ),
        .dest_clk  ( ddr_clk_o      ),
        .dest_arst ( axi_resetn_ui  )
    );

    `DECLARE_AXI_BUS(to_clk_conv, DDR2_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)
    `DECLARE_AXI_BUS(to_mig, DDR2_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    // System Cache handles width conversion and AXI exclusive accesses.
    xlnx_system_cache_0 system_cache_u (
        .ACLK               ( clock_i                 ),
        .ARESETN            ( axi_resetn_soc          ),
        .Initializing       (                        ),
        .S0_AXI_GEN_AWID    ( s_axi_awid              ),
        .S0_AXI_GEN_AWADDR  ( s_axi_awaddr            ),
        .S0_AXI_GEN_AWLEN   ( s_axi_awlen             ),
        .S0_AXI_GEN_AWSIZE  ( s_axi_awsize            ),
        .S0_AXI_GEN_AWBURST ( s_axi_awburst           ),
        .S0_AXI_GEN_AWLOCK  ( s_axi_awlock            ),
        .S0_AXI_GEN_AWCACHE ( s_axi_awcache           ),
        .S0_AXI_GEN_AWPROT  ( s_axi_awprot            ),
        .S0_AXI_GEN_AWQOS   ( s_axi_awqos             ),
        .S0_AXI_GEN_AWVALID ( s_axi_awvalid           ),
        .S0_AXI_GEN_AWREADY ( s_axi_awready           ),
        .S0_AXI_GEN_AWUSER  ( 32'b0                   ),
        .S0_AXI_GEN_WDATA   ( s_axi_wdata             ),
        .S0_AXI_GEN_WSTRB   ( s_axi_wstrb             ),
        .S0_AXI_GEN_WLAST   ( s_axi_wlast             ),
        .S0_AXI_GEN_WVALID  ( s_axi_wvalid            ),
        .S0_AXI_GEN_WREADY  ( s_axi_wready            ),
        .S0_AXI_GEN_BRESP   ( s_axi_bresp             ),
        .S0_AXI_GEN_BID     ( s_axi_bid               ),
        .S0_AXI_GEN_BVALID  ( s_axi_bvalid            ),
        .S0_AXI_GEN_BREADY  ( s_axi_bready            ),
        .S0_AXI_GEN_ARID    ( s_axi_arid              ),
        .S0_AXI_GEN_ARADDR  ( s_axi_araddr            ),
        .S0_AXI_GEN_ARLEN   ( s_axi_arlen             ),
        .S0_AXI_GEN_ARSIZE  ( s_axi_arsize            ),
        .S0_AXI_GEN_ARBURST ( s_axi_arburst           ),
        .S0_AXI_GEN_ARLOCK  ( s_axi_arlock            ),
        .S0_AXI_GEN_ARCACHE ( s_axi_arcache           ),
        .S0_AXI_GEN_ARPROT  ( s_axi_arprot            ),
        .S0_AXI_GEN_ARQOS   ( s_axi_arqos             ),
        .S0_AXI_GEN_ARVALID ( s_axi_arvalid           ),
        .S0_AXI_GEN_ARREADY ( s_axi_arready           ),
        .S0_AXI_GEN_ARUSER  ( 32'b0                   ),
        .S0_AXI_GEN_RID     ( s_axi_rid               ),
        .S0_AXI_GEN_RDATA   ( s_axi_rdata             ),
        .S0_AXI_GEN_RRESP   ( s_axi_rresp             ),
        .S0_AXI_GEN_RLAST   ( s_axi_rlast             ),
        .S0_AXI_GEN_RVALID  ( s_axi_rvalid            ),
        .S0_AXI_GEN_RREADY  ( s_axi_rready            ),
        .M0_AXI_AWID        ( to_clk_conv_axi_awid    ),
        .M0_AXI_AWADDR      ( to_clk_conv_axi_awaddr  ),
        .M0_AXI_AWLEN       ( to_clk_conv_axi_awlen   ),
        .M0_AXI_AWSIZE      ( to_clk_conv_axi_awsize  ),
        .M0_AXI_AWBURST     ( to_clk_conv_axi_awburst ),
        .M0_AXI_AWLOCK      ( to_clk_conv_axi_awlock  ),
        .M0_AXI_AWCACHE     ( to_clk_conv_axi_awcache ),
        .M0_AXI_AWPROT      ( to_clk_conv_axi_awprot  ),
        .M0_AXI_AWQOS       ( to_clk_conv_axi_awqos   ),
        .M0_AXI_AWVALID     ( to_clk_conv_axi_awvalid ),
        .M0_AXI_AWREADY     ( to_clk_conv_axi_awready ),
        .M0_AXI_WDATA       ( to_clk_conv_axi_wdata   ),
        .M0_AXI_WSTRB       ( to_clk_conv_axi_wstrb   ),
        .M0_AXI_WLAST       ( to_clk_conv_axi_wlast   ),
        .M0_AXI_WVALID      ( to_clk_conv_axi_wvalid  ),
        .M0_AXI_WREADY      ( to_clk_conv_axi_wready  ),
        .M0_AXI_BRESP       ( to_clk_conv_axi_bresp   ),
        .M0_AXI_BID         ( to_clk_conv_axi_bid     ),
        .M0_AXI_BVALID      ( to_clk_conv_axi_bvalid  ),
        .M0_AXI_BREADY      ( to_clk_conv_axi_bready  ),
        .M0_AXI_ARID        ( to_clk_conv_axi_arid    ),
        .M0_AXI_ARADDR      ( to_clk_conv_axi_araddr  ),
        .M0_AXI_ARLEN       ( to_clk_conv_axi_arlen   ),
        .M0_AXI_ARSIZE      ( to_clk_conv_axi_arsize  ),
        .M0_AXI_ARBURST     ( to_clk_conv_axi_arburst ),
        .M0_AXI_ARLOCK      ( to_clk_conv_axi_arlock  ),
        .M0_AXI_ARCACHE     ( to_clk_conv_axi_arcache ),
        .M0_AXI_ARPROT      ( to_clk_conv_axi_arprot  ),
        .M0_AXI_ARQOS       ( to_clk_conv_axi_arqos   ),
        .M0_AXI_ARVALID     ( to_clk_conv_axi_arvalid ),
        .M0_AXI_ARREADY     ( to_clk_conv_axi_arready ),
        .M0_AXI_RID         ( to_clk_conv_axi_rid     ),
        .M0_AXI_RDATA       ( to_clk_conv_axi_rdata   ),
        .M0_AXI_RRESP       ( to_clk_conv_axi_rresp   ),
        .M0_AXI_RLAST       ( to_clk_conv_axi_rlast   ),
        .M0_AXI_RVALID      ( to_clk_conv_axi_rvalid  ),
        .M0_AXI_RREADY      ( to_clk_conv_axi_rready  )
    );

    // System Cache has no AXI region outputs.
    assign to_clk_conv_axi_awregion = '0;
    assign to_clk_conv_axi_arregion = '0;

    axi_clock_converter_wrapper #(
        .LOCAL_DATA_WIDTH ( DDR2_DATA_WIDTH  ),
        .LOCAL_ADDR_WIDTH ( LOCAL_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH   ( LOCAL_ID_WIDTH   )
    ) axi_clk_conv_u (
        .s_axi_aclk    ( clock_i        ),
        .s_axi_aresetn ( axi_resetn_soc ),
        .m_axi_aclk    ( ddr_clk_o      ),
        .m_axi_aresetn ( axi_resetn_ui  ),
        .s_axi_awid       ( to_clk_conv_axi_awid ),
        .s_axi_awaddr     ( to_clk_conv_axi_awaddr ),
        .s_axi_awlen      ( to_clk_conv_axi_awlen ),
        .s_axi_awsize     ( to_clk_conv_axi_awsize ),
        .s_axi_awburst    ( to_clk_conv_axi_awburst ),
        .s_axi_awlock     ( to_clk_conv_axi_awlock ),
        .s_axi_awcache    ( to_clk_conv_axi_awcache ),
        .s_axi_awprot     ( to_clk_conv_axi_awprot ),
        .s_axi_awregion   ( to_clk_conv_axi_awregion ),
        .s_axi_awqos      ( to_clk_conv_axi_awqos ),
        .s_axi_awvalid    ( to_clk_conv_axi_awvalid ),
        .s_axi_awready    ( to_clk_conv_axi_awready ),
        .s_axi_wdata      ( to_clk_conv_axi_wdata ),
        .s_axi_wstrb      ( to_clk_conv_axi_wstrb ),
        .s_axi_wlast      ( to_clk_conv_axi_wlast ),
        .s_axi_wvalid     ( to_clk_conv_axi_wvalid ),
        .s_axi_wready     ( to_clk_conv_axi_wready ),
        .s_axi_bid        ( to_clk_conv_axi_bid ),
        .s_axi_bresp      ( to_clk_conv_axi_bresp ),
        .s_axi_bvalid     ( to_clk_conv_axi_bvalid ),
        .s_axi_bready     ( to_clk_conv_axi_bready ),
        .s_axi_arid       ( to_clk_conv_axi_arid ),
        .s_axi_araddr     ( to_clk_conv_axi_araddr ),
        .s_axi_arlen      ( to_clk_conv_axi_arlen ),
        .s_axi_arsize     ( to_clk_conv_axi_arsize ),
        .s_axi_arburst    ( to_clk_conv_axi_arburst ),
        .s_axi_arlock     ( to_clk_conv_axi_arlock ),
        .s_axi_arcache    ( to_clk_conv_axi_arcache ),
        .s_axi_arprot     ( to_clk_conv_axi_arprot ),
        .s_axi_arregion   ( to_clk_conv_axi_arregion ),
        .s_axi_arqos      ( to_clk_conv_axi_arqos ),
        .s_axi_arvalid    ( to_clk_conv_axi_arvalid ),
        .s_axi_arready    ( to_clk_conv_axi_arready ),
        .s_axi_rid        ( to_clk_conv_axi_rid ),
        .s_axi_rdata      ( to_clk_conv_axi_rdata ),
        .s_axi_rresp      ( to_clk_conv_axi_rresp ),
        .s_axi_rlast      ( to_clk_conv_axi_rlast ),
        .s_axi_rvalid     ( to_clk_conv_axi_rvalid ),
        .s_axi_rready     ( to_clk_conv_axi_rready ),
        .m_axi_awid       ( to_mig_axi_awid ),
        .m_axi_awaddr     ( to_mig_axi_awaddr ),
        .m_axi_awlen      ( to_mig_axi_awlen ),
        .m_axi_awsize     ( to_mig_axi_awsize ),
        .m_axi_awburst    ( to_mig_axi_awburst ),
        .m_axi_awlock     ( to_mig_axi_awlock ),
        .m_axi_awcache    ( to_mig_axi_awcache ),
        .m_axi_awprot     ( to_mig_axi_awprot ),
        .m_axi_awregion   ( to_mig_axi_awregion ),
        .m_axi_awqos      ( to_mig_axi_awqos ),
        .m_axi_awvalid    ( to_mig_axi_awvalid ),
        .m_axi_awready    ( to_mig_axi_awready ),
        .m_axi_wdata      ( to_mig_axi_wdata ),
        .m_axi_wstrb      ( to_mig_axi_wstrb ),
        .m_axi_wlast      ( to_mig_axi_wlast ),
        .m_axi_wvalid     ( to_mig_axi_wvalid ),
        .m_axi_wready     ( to_mig_axi_wready ),
        .m_axi_bid        ( to_mig_axi_bid ),
        .m_axi_bresp      ( to_mig_axi_bresp ),
        .m_axi_bvalid     ( to_mig_axi_bvalid ),
        .m_axi_bready     ( to_mig_axi_bready ),
        .m_axi_arid       ( to_mig_axi_arid ),
        .m_axi_araddr     ( to_mig_axi_araddr ),
        .m_axi_arlen      ( to_mig_axi_arlen ),
        .m_axi_arsize     ( to_mig_axi_arsize ),
        .m_axi_arburst    ( to_mig_axi_arburst ),
        .m_axi_arlock     ( to_mig_axi_arlock ),
        .m_axi_arcache    ( to_mig_axi_arcache ),
        .m_axi_arprot     ( to_mig_axi_arprot ),
        .m_axi_arregion   ( to_mig_axi_arregion ),
        .m_axi_arqos      ( to_mig_axi_arqos ),
        .m_axi_arvalid    ( to_mig_axi_arvalid ),
        .m_axi_arready    ( to_mig_axi_arready ),
        .m_axi_rid        ( to_mig_axi_rid ),
        .m_axi_rdata      ( to_mig_axi_rdata ),
        .m_axi_rresp      ( to_mig_axi_rresp ),
        .m_axi_rlast      ( to_mig_axi_rlast ),
        .m_axi_rvalid     ( to_mig_axi_rvalid ),
        .m_axi_rready     ( to_mig_axi_rready )
    );

    xlnx_ddr2_mig ddr2_mig_u (
        .sys_clk_i           ( clk_200mhz_i          ),
        // The board MIG preset uses an active-low system reset.
        .sys_rst             ( sys_reset_ni          ),
        .ui_clk              ( ddr_clk_o             ),
        .ui_clk_sync_rst     ( ui_clk_sync_rst       ),
        .init_calib_complete ( init_calib_complete_o ),
        .aresetn             ( axi_resetn_ui         ),
        .ui_addn_clk_0       (                       ),
        .ui_addn_clk_1       (                       ),
        .ui_addn_clk_2       (                       ),
        .ui_addn_clk_3       (                       ),
        .ui_addn_clk_4       (                       ),
        .mmcm_locked         (                       ),
        .app_sr_req          ( 1'b0                  ),
        .app_ref_req         ( 1'b0                  ),
        .app_zq_req          ( 1'b0                  ),
        .app_sr_active       (                       ),
        .app_ref_ack         (                       ),
        .app_zq_ack          (                       ),
        .ddr2_dq          ( ddr2_dq ),
        .ddr2_dqs_n       ( ddr2_dqs_n ),
        .ddr2_dqs_p       ( ddr2_dqs_p ),
        .ddr2_addr        ( ddr2_addr ),
        .ddr2_ba          ( ddr2_ba ),
        .ddr2_ras_n       ( ddr2_ras_n ),
        .ddr2_cas_n       ( ddr2_cas_n ),
        .ddr2_we_n        ( ddr2_we_n ),
        .ddr2_ck_p        ( ddr2_ck_p ),
        .ddr2_ck_n        ( ddr2_ck_n ),
        .ddr2_cke         ( ddr2_cke ),
        .ddr2_cs_n        ( ddr2_cs_n ),
        .ddr2_dm          ( ddr2_dm ),
        .ddr2_odt         ( ddr2_odt ),
        .s_axi_awid       ( to_mig_axi_awid ),
        .s_axi_awaddr     ( to_mig_axi_awaddr[DDR2_ADDR_WIDTH-1:0] ),
        .s_axi_awlen      ( to_mig_axi_awlen ),
        .s_axi_awsize     ( to_mig_axi_awsize ),
        .s_axi_awburst    ( to_mig_axi_awburst ),
        .s_axi_awlock     ( to_mig_axi_awlock ),
        .s_axi_awcache    ( to_mig_axi_awcache ),
        .s_axi_awprot     ( to_mig_axi_awprot ),
        .s_axi_awqos      ( to_mig_axi_awqos ),
        .s_axi_awvalid    ( to_mig_axi_awvalid ),
        .s_axi_awready    ( to_mig_axi_awready ),
        .s_axi_wdata      ( to_mig_axi_wdata ),
        .s_axi_wstrb      ( to_mig_axi_wstrb ),
        .s_axi_wlast      ( to_mig_axi_wlast ),
        .s_axi_wvalid     ( to_mig_axi_wvalid ),
        .s_axi_wready     ( to_mig_axi_wready ),
        .s_axi_bid        ( to_mig_axi_bid ),
        .s_axi_bresp      ( to_mig_axi_bresp ),
        .s_axi_bvalid     ( to_mig_axi_bvalid ),
        .s_axi_bready     ( to_mig_axi_bready ),
        .s_axi_arid       ( to_mig_axi_arid ),
        .s_axi_araddr     ( to_mig_axi_araddr[DDR2_ADDR_WIDTH-1:0] ),
        .s_axi_arlen      ( to_mig_axi_arlen ),
        .s_axi_arsize     ( to_mig_axi_arsize ),
        .s_axi_arburst    ( to_mig_axi_arburst ),
        .s_axi_arlock     ( to_mig_axi_arlock ),
        .s_axi_arcache    ( to_mig_axi_arcache ),
        .s_axi_arprot     ( to_mig_axi_arprot ),
        .s_axi_arqos      ( to_mig_axi_arqos ),
        .s_axi_arvalid    ( to_mig_axi_arvalid ),
        .s_axi_arready    ( to_mig_axi_arready ),
        .s_axi_rid        ( to_mig_axi_rid ),
        .s_axi_rdata      ( to_mig_axi_rdata ),
        .s_axi_rresp      ( to_mig_axi_rresp ),
        .s_axi_rlast      ( to_mig_axi_rlast ),
        .s_axi_rvalid     ( to_mig_axi_rvalid ),
        .s_axi_rready     ( to_mig_axi_rready )
    );

endmodule
