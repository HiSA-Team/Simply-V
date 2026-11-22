// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Description: This module is a wrapper for a single Nexys A7 DDR2 channel.
//              It includes :
//                 - A clock converter from the SoC clock to the MIG UI clock
//                 - A datawidth converter from 32/64 bit to 128 bit
//                 - A DDR2 (MIG) IP
//                 - AXI reset synchronization, held until calibration completes
//
//              It has the following sub-architecture:
//
//   Main Clock Domain                  DDR2 UI Clock Domain
//   DATA: 32/64 bit                    DATA: 32/64 bit -> 128 bit
//                 _____________            _____________            ____________
//   s_axi ------>|    Clock    |--------->|   Dwidth    |--------->|            |
//                | Converter   | to_dwidth| Converter   |   to_mig | DDR2 (MIG) |---> DDR2
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
    input logic sys_clk_i,
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

    `DECLARE_AXI_BUS(to_dwidth, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)
    `DECLARE_AXI_BUS(to_mig, DDR2_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)

    axi_clock_converter_wrapper #(
        .LOCAL_DATA_WIDTH ( LOCAL_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH ( LOCAL_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH   ( LOCAL_ID_WIDTH   )
    ) axi_clk_conv_u (
        .s_axi_aclk    ( clock_i        ),
        .s_axi_aresetn ( axi_resetn_soc ),
        .m_axi_aclk    ( ddr_clk_o      ),
        .m_axi_aresetn ( axi_resetn_ui  ),
        .s_axi_awid       ( s_axi_awid ),
        .s_axi_awaddr     ( s_axi_awaddr ),
        .s_axi_awlen      ( s_axi_awlen ),
        .s_axi_awsize     ( s_axi_awsize ),
        .s_axi_awburst    ( s_axi_awburst ),
        .s_axi_awlock     ( s_axi_awlock ),
        .s_axi_awcache    ( s_axi_awcache ),
        .s_axi_awprot     ( s_axi_awprot ),
        .s_axi_awregion   ( s_axi_awregion ),
        .s_axi_awqos      ( s_axi_awqos ),
        .s_axi_awvalid    ( s_axi_awvalid ),
        .s_axi_awready    ( s_axi_awready ),
        .s_axi_wdata      ( s_axi_wdata ),
        .s_axi_wstrb      ( s_axi_wstrb ),
        .s_axi_wlast      ( s_axi_wlast ),
        .s_axi_wvalid     ( s_axi_wvalid ),
        .s_axi_wready     ( s_axi_wready ),
        .s_axi_bid        ( s_axi_bid ),
        .s_axi_bresp      ( s_axi_bresp ),
        .s_axi_bvalid     ( s_axi_bvalid ),
        .s_axi_bready     ( s_axi_bready ),
        .s_axi_arid       ( s_axi_arid ),
        .s_axi_araddr     ( s_axi_araddr ),
        .s_axi_arlen      ( s_axi_arlen ),
        .s_axi_arsize     ( s_axi_arsize ),
        .s_axi_arburst    ( s_axi_arburst ),
        .s_axi_arlock     ( s_axi_arlock ),
        .s_axi_arcache    ( s_axi_arcache ),
        .s_axi_arprot     ( s_axi_arprot ),
        .s_axi_arregion   ( s_axi_arregion ),
        .s_axi_arqos      ( s_axi_arqos ),
        .s_axi_arvalid    ( s_axi_arvalid ),
        .s_axi_arready    ( s_axi_arready ),
        .s_axi_rid        ( s_axi_rid ),
        .s_axi_rdata      ( s_axi_rdata ),
        .s_axi_rresp      ( s_axi_rresp ),
        .s_axi_rlast      ( s_axi_rlast ),
        .s_axi_rvalid     ( s_axi_rvalid ),
        .s_axi_rready     ( s_axi_rready ),
        .m_axi_awid       ( to_dwidth_axi_awid ),
        .m_axi_awaddr     ( to_dwidth_axi_awaddr ),
        .m_axi_awlen      ( to_dwidth_axi_awlen ),
        .m_axi_awsize     ( to_dwidth_axi_awsize ),
        .m_axi_awburst    ( to_dwidth_axi_awburst ),
        .m_axi_awlock     ( to_dwidth_axi_awlock ),
        .m_axi_awcache    ( to_dwidth_axi_awcache ),
        .m_axi_awprot     ( to_dwidth_axi_awprot ),
        .m_axi_awregion   ( to_dwidth_axi_awregion ),
        .m_axi_awqos      ( to_dwidth_axi_awqos ),
        .m_axi_awvalid    ( to_dwidth_axi_awvalid ),
        .m_axi_awready    ( to_dwidth_axi_awready ),
        .m_axi_wdata      ( to_dwidth_axi_wdata ),
        .m_axi_wstrb      ( to_dwidth_axi_wstrb ),
        .m_axi_wlast      ( to_dwidth_axi_wlast ),
        .m_axi_wvalid     ( to_dwidth_axi_wvalid ),
        .m_axi_wready     ( to_dwidth_axi_wready ),
        .m_axi_bid        ( to_dwidth_axi_bid ),
        .m_axi_bresp      ( to_dwidth_axi_bresp ),
        .m_axi_bvalid     ( to_dwidth_axi_bvalid ),
        .m_axi_bready     ( to_dwidth_axi_bready ),
        .m_axi_arid       ( to_dwidth_axi_arid ),
        .m_axi_araddr     ( to_dwidth_axi_araddr ),
        .m_axi_arlen      ( to_dwidth_axi_arlen ),
        .m_axi_arsize     ( to_dwidth_axi_arsize ),
        .m_axi_arburst    ( to_dwidth_axi_arburst ),
        .m_axi_arlock     ( to_dwidth_axi_arlock ),
        .m_axi_arcache    ( to_dwidth_axi_arcache ),
        .m_axi_arprot     ( to_dwidth_axi_arprot ),
        .m_axi_arregion   ( to_dwidth_axi_arregion ),
        .m_axi_arqos      ( to_dwidth_axi_arqos ),
        .m_axi_arvalid    ( to_dwidth_axi_arvalid ),
        .m_axi_arready    ( to_dwidth_axi_arready ),
        .m_axi_rid        ( to_dwidth_axi_rid ),
        .m_axi_rdata      ( to_dwidth_axi_rdata ),
        .m_axi_rresp      ( to_dwidth_axi_rresp ),
        .m_axi_rlast      ( to_dwidth_axi_rlast ),
        .m_axi_rvalid     ( to_dwidth_axi_rvalid ),
        .m_axi_rready     ( to_dwidth_axi_rready )
    );

    // The upsizer has one downstream ID thread and restores source IDs.
    assign to_mig_axi_awid = '0;
    assign to_mig_axi_arid = '0;

    xlnx_axi_dwidth_to128_converter axi_dwidth_conv_u (
        .s_axi_aclk    ( ddr_clk_o     ),
        .s_axi_aresetn ( axi_resetn_ui ),
        .s_axi_awid       ( to_dwidth_axi_awid ),
        .s_axi_awaddr     ( to_dwidth_axi_awaddr ),
        .s_axi_awlen      ( to_dwidth_axi_awlen ),
        .s_axi_awsize     ( to_dwidth_axi_awsize ),
        .s_axi_awburst    ( to_dwidth_axi_awburst ),
        .s_axi_awlock     ( to_dwidth_axi_awlock ),
        .s_axi_awcache    ( to_dwidth_axi_awcache ),
        .s_axi_awprot     ( to_dwidth_axi_awprot ),
        .s_axi_awregion   ( to_dwidth_axi_awregion ),
        .s_axi_awqos      ( to_dwidth_axi_awqos ),
        .s_axi_awvalid    ( to_dwidth_axi_awvalid ),
        .s_axi_awready    ( to_dwidth_axi_awready ),
        .s_axi_wdata      ( to_dwidth_axi_wdata ),
        .s_axi_wstrb      ( to_dwidth_axi_wstrb ),
        .s_axi_wlast      ( to_dwidth_axi_wlast ),
        .s_axi_wvalid     ( to_dwidth_axi_wvalid ),
        .s_axi_wready     ( to_dwidth_axi_wready ),
        .s_axi_bid        ( to_dwidth_axi_bid ),
        .s_axi_bresp      ( to_dwidth_axi_bresp ),
        .s_axi_bvalid     ( to_dwidth_axi_bvalid ),
        .s_axi_bready     ( to_dwidth_axi_bready ),
        .s_axi_arid       ( to_dwidth_axi_arid ),
        .s_axi_araddr     ( to_dwidth_axi_araddr ),
        .s_axi_arlen      ( to_dwidth_axi_arlen ),
        .s_axi_arsize     ( to_dwidth_axi_arsize ),
        .s_axi_arburst    ( to_dwidth_axi_arburst ),
        .s_axi_arlock     ( to_dwidth_axi_arlock ),
        .s_axi_arcache    ( to_dwidth_axi_arcache ),
        .s_axi_arprot     ( to_dwidth_axi_arprot ),
        .s_axi_arregion   ( to_dwidth_axi_arregion ),
        .s_axi_arqos      ( to_dwidth_axi_arqos ),
        .s_axi_arvalid    ( to_dwidth_axi_arvalid ),
        .s_axi_arready    ( to_dwidth_axi_arready ),
        .s_axi_rid        ( to_dwidth_axi_rid ),
        .s_axi_rdata      ( to_dwidth_axi_rdata ),
        .s_axi_rresp      ( to_dwidth_axi_rresp ),
        .s_axi_rlast      ( to_dwidth_axi_rlast ),
        .s_axi_rvalid     ( to_dwidth_axi_rvalid ),
        .s_axi_rready     ( to_dwidth_axi_rready ),
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
        .m_axi_bresp      ( to_mig_axi_bresp ),
        .m_axi_bvalid     ( to_mig_axi_bvalid ),
        .m_axi_bready     ( to_mig_axi_bready ),
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
        .m_axi_rdata      ( to_mig_axi_rdata ),
        .m_axi_rresp      ( to_mig_axi_rresp ),
        .m_axi_rlast      ( to_mig_axi_rlast ),
        .m_axi_rvalid     ( to_mig_axi_rvalid ),
        .m_axi_rready     ( to_mig_axi_rready )
    );

    xlnx_ddr2_mig ddr2_mig_u (
        .sys_clk_i           ( sys_clk_i             ),
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
