// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Description:
//    This module is intended as a top-level wrapper for the custom_cv64a6
//    unit used in the SoC rtl (in the Socket). It wraps the CV64A6 CPU from OpenHW.
//    By default, CV64A6 expects a configuration file describing its extensions
//    Cache sizes and microarchitectural features, such as RAS or BTB size.
//    We use a slightly modified config file suited on our needs in ./assets.
//    Extensions supported are: I M A F D C H


// Import headers
`include "uninasoc_axi.svh"
`include "uninasoc_mem.svh"

`include "axi_typedef.svh"

module custom_top_wrapper # (

    //////////////////////////////////////
    //  Add here IP-related parameters  //
    //////////////////////////////////////

    // TODO121: Automatically align with config
    parameter LOCAL_AXI_DATA_WIDTH    = 64,
    parameter LOCAL_AXI_ADDR_WIDTH    = 64,
    parameter LOCAL_AXI_STRB_WIDTH    = LOCAL_AXI_DATA_WIDTH / 8,
    parameter LOCAL_AXI_ID_WIDTH      = 4,
    parameter LOCAL_AXI_REGION_WIDTH  = 4,
    parameter LOCAL_AXI_LEN_WIDTH     = 8,
    parameter LOCAL_AXI_SIZE_WIDTH    = 3,
    parameter LOCAL_AXI_BURST_WIDTH   = 2,
    parameter LOCAL_AXI_LOCK_WIDTH    = 1,
    parameter LOCAL_AXI_CACHE_WIDTH   = 4,
    parameter LOCAL_AXI_PROT_WIDTH    = 3,
    parameter LOCAL_AXI_QOS_WIDTH     = 4,
    parameter LOCAL_AXI_VALID_WIDTH   = 1,
    parameter LOCAL_AXI_READY_WIDTH   = 1,
    parameter LOCAL_AXI_LAST_WIDTH    = 1,
    parameter LOCAL_AXI_RESP_WIDTH    = 2,
    parameter LOCAL_AXI_USER_WIDTH    = 64

) (

    ///////////////////////////////////
    //  Add here IP-related signals  //
    ///////////////////////////////////

    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Reset boot address - SUBSYSTEM
    input logic [64-1:0] boot_addr_i,
    // Hard ID reflected as CSR - SUBSYSTEM
    input logic [64-1:0] hart_id_i,
    // Level sensitive (async) interrupts - SUBSYSTEM
    input logic [1:0] irq_i,
    // Inter-processor (async) interrupt - SUBSYSTEM
    input logic ipi_i,
    // Timer (async) interrupt - SUBSYSTEM
    input logic time_irq_i,
    // Debug (async) request - SUBSYSTEM
    input logic debug_req_i,
    // Probes to build RVFI, can be left open when not used - RVFI
    // output rvfi_probes_t rvfi_probes_o,
    // // CVXIF request - SUBSYSTEM
    // output cvxif_req_t cvxif_req_o,
    // // CVXIF response - SUBSYSTEM
    // input cvxif_resp_t cvxif_resp_i,

    ////////////////////////////
    //  Bus Array Interfaces  //
    ////////////////////////////

    // AXI Master Interface Array
    `DEFINE_AXI_MASTER_PORTS(m, LOCAL_AXI_DATA_WIDTH, LOCAL_AXI_ADDR_WIDTH, LOCAL_AXI_ID_WIDTH)
);

  // Baseline noc_req_t type is the axi_typedef.svh axi format
  `AXI_TYPEDEF_ALL(
    axi,
    logic [LOCAL_AXI_ADDR_WIDTH-1:0],
    logic [LOCAL_AXI_ID_WIDTH-1:0],
    logic [LOCAL_AXI_DATA_WIDTH-1:0],
    logic [LOCAL_AXI_STRB_WIDTH-1:0],
    logic [LOCAL_AXI_USER_WIDTH-1:0]  // This is for the user field, which is missing from our interface (or unused)
  )

  axi_req_t axi_req;
  axi_resp_t axi_rsp;

  cva6 #(

  ) cva6_u (

    .clk_i          ( clk_i       ),
    .rst_ni         ( rst_ni      ),
    .boot_addr_i    ( boot_addr_i ),
    .hart_id_i      ( hart_id_i   ),
    .irq_i          ( irq_i       ),
    .ipi_i          ( ipi_i       ),
    .time_irq_i     ( time_irq_i  ),
    .debug_req_i    ( debug_req_i ),
    .rvfi_probes_o  (             ),
    .cvxif_req_o    (             ),
    .cvxif_resp_i   ( '0          ),
    .noc_req_o      ( axi_req     ),
    .noc_resp_i     ( axi_rsp     )
  );

  // Map master port signals
  assign m_axi_awid      = axi_req.aw.id;
  assign m_axi_awaddr    = axi_req.aw.addr;
  assign m_axi_awlen     = axi_req.aw.len;
  assign m_axi_awsize    = axi_req.aw.size;
  assign m_axi_awburst   = axi_req.aw.burst;
  assign m_axi_awlock    = axi_req.aw.lock;
  assign m_axi_awcache   = axi_req.aw.cache;
  assign m_axi_awprot    = axi_req.aw.prot;
  assign m_axi_awqos     = axi_req.aw.qos;
  assign m_axi_awregion  = axi_req.aw.region;
  assign m_axi_awvalid   = axi_req.aw_valid;
  assign m_axi_wdata     = axi_req.w.data;
  assign m_axi_wstrb     = axi_req.w.strb;
  assign m_axi_wlast     = axi_req.w.last;
  assign m_axi_wvalid    = axi_req.w_valid;
  assign m_axi_bready    = axi_req.b_ready;
  assign m_axi_araddr    = axi_req.ar.addr;
  assign m_axi_arlen     = axi_req.ar.len;
  assign m_axi_arsize    = axi_req.ar.size;
  assign m_axi_arburst   = axi_req.ar.burst;
  assign m_axi_arlock    = axi_req.ar.lock;
  assign m_axi_arcache   = axi_req.ar.cache;
  assign m_axi_arprot    = axi_req.ar.prot;
  assign m_axi_arqos     = axi_req.ar.qos;
  assign m_axi_arregion  = axi_req.ar.region;
  assign m_axi_arvalid   = axi_req.ar_valid;
  assign m_axi_rready    = axi_req.r_ready;
  assign m_axi_arid      = axi_req.ar.id;

  assign axi_rsp.aw_ready = m_axi_awready;
  assign axi_rsp.w_ready  = m_axi_wready;
  assign axi_rsp.b.id     = m_axi_bid;
  assign axi_rsp.b.resp   = m_axi_bresp;
  assign axi_rsp.b_valid  = m_axi_bvalid;
  assign axi_rsp.ar_ready = m_axi_arready;
  assign axi_rsp.r.id     = m_axi_rid;
  assign axi_rsp.r.data   = m_axi_rdata;
  assign axi_rsp.r.resp   = m_axi_rresp;
  assign axi_rsp.r.last   = m_axi_rlast;
  assign axi_rsp.r_valid  = m_axi_rvalid;

endmodule : custom_top_wrapper
