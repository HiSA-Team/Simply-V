// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valerio.didomenico@unina.it>
// Description:
//    This module is intended as a top-level wrapper for the custom_cv64a6
//    unit used in the SoC rtl (in the Socket). It wraps the CV64A6 CPU from OpenHW.
//    By default, CV64A6 expects a configuration file describing its extensions
//    Cache sizes and microarchitectural features, such as RAS or BTB size.
//    We use a slightly modified config file suited on our needs in ./assets.
//    Extensions supported are: I M A F D C H
//    The wrapper also instantiates the 'axi_riscv_atomics' module, which handles
//    LR/SC and AMO instructions by translating them into standard AXI transactions,
//    ensuring proper atomic operation support on AXI-based memory systems.


// Import headers
`include "simplyv_axi.svh"
`include "simplyv_mem.svh"

`include "axi_typedef.svh"

module custom_top_wrapper # (

    //////////////////////////////////////
    //  Add here IP-related parameters  //
    //////////////////////////////////////

    // TODO121: Automatically align with config
    parameter LOCAL_AXI_DATA_WIDTH    = 64,
    parameter LOCAL_AXI_ADDR_WIDTH    = 64,
    parameter LOCAL_AXI_STRB_WIDTH    = LOCAL_AXI_DATA_WIDTH / 8,
    parameter LOCAL_AXI_ID_WIDTH      = 4, // CV64A6 ID with MUST be 4
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
    parameter LOCAL_AXI_USER_WIDTH    = 64,
    parameter USE_ATOMICS             = 0

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
generate
  if(USE_ATOMICS) begin : gen_with_atomics
    axi_riscv_atomics #(
            .AXI_ADDR_WIDTH     (LOCAL_AXI_ADDR_WIDTH),
            .AXI_DATA_WIDTH     (LOCAL_AXI_DATA_WIDTH),
            .AXI_ID_WIDTH       (LOCAL_AXI_ID_WIDTH),
            .AXI_USER_WIDTH     (LOCAL_AXI_USER_WIDTH),
            .AXI_MAX_WRITE_TXNS (1),
            .RISCV_WORD_WIDTH   (64)
        ) i_atomics (
            .clk_i           ( clk_i         ),
            .rst_ni          ( rst_ni        ),
            .slv_aw_addr_i   ( axi_req.aw.addr   ),
            .slv_aw_prot_i   ( axi_req.aw.prot   ),
            .slv_aw_region_i ( axi_req.aw.region ),
            .slv_aw_atop_i   ( axi_req.aw.atop   ),
            .slv_aw_len_i    ( axi_req.aw.len    ),
            .slv_aw_size_i   ( axi_req.aw.size   ),
            .slv_aw_burst_i  ( axi_req.aw.burst  ),
            .slv_aw_lock_i   ( axi_req.aw.lock   ),
            .slv_aw_cache_i  ( axi_req.aw.cache  ),
            .slv_aw_qos_i    ( axi_req.aw.qos    ),
            .slv_aw_id_i     ( axi_req.aw.id     ),
            .slv_aw_user_i   ( axi_req.aw.user   ),
            .slv_aw_ready_o  ( axi_rsp.aw_ready  ),
            .slv_aw_valid_i  ( axi_req.aw_valid  ),
            .slv_ar_addr_i   ( axi_req.ar.addr   ),
            .slv_ar_prot_i   ( axi_req.ar.prot   ),
            .slv_ar_region_i ( axi_req.ar.region ),
            .slv_ar_len_i    ( axi_req.ar.len    ),
            .slv_ar_size_i   ( axi_req.ar.size   ),
            .slv_ar_burst_i  ( axi_req.ar.burst  ),
            .slv_ar_lock_i   ( axi_req.ar.lock   ),
            .slv_ar_cache_i  ( axi_req.ar.cache  ),
            .slv_ar_qos_i    ( axi_req.ar.qos    ),
            .slv_ar_id_i     ( axi_req.ar.id     ),
            .slv_ar_user_i   ( axi_req.ar.user   ),
            .slv_ar_ready_o  ( axi_rsp.ar_ready  ),
            .slv_ar_valid_i  ( axi_req.ar_valid  ),
            .slv_w_data_i    ( axi_req.w.data    ),
            .slv_w_strb_i    ( axi_req.w.strb    ),
            .slv_w_user_i    ( axi_req.w.user    ),
            .slv_w_last_i    ( axi_req.w.last    ),
            .slv_w_ready_o   ( axi_rsp.w_ready   ),
            .slv_w_valid_i   ( axi_req.w_valid   ),
            .slv_r_data_o    ( axi_rsp.r.data    ),
            .slv_r_resp_o    ( axi_rsp.r.resp    ),
            .slv_r_last_o    ( axi_rsp.r.last    ),
            .slv_r_id_o      ( axi_rsp.r.id      ),
            .slv_r_user_o    ( axi_rsp.r.user    ),
            .slv_r_ready_i   ( axi_req.r_ready  ),
            .slv_r_valid_o   ( axi_rsp.r_valid   ),
            .slv_b_resp_o    ( axi_rsp.b.resp    ),
            .slv_b_id_o      ( axi_rsp.b.id      ),
            .slv_b_user_o    ( axi_rsp.b.user    ),
            .slv_b_ready_i   ( axi_req.b_ready   ),
            .slv_b_valid_o   ( axi_rsp.b_valid   ),
            .mst_aw_addr_o   ( m_axi_awaddr   ),
            .mst_aw_prot_o   ( m_axi_awprot   ),
            .mst_aw_region_o ( m_axi_awregion ),
            .mst_aw_atop_o   ( m_axi_awatop   ),
            .mst_aw_len_o    ( m_axi_awlen    ),
            .mst_aw_size_o   ( m_axi_awsize   ),
            .mst_aw_burst_o  ( m_axi_awburst  ),
            .mst_aw_lock_o   ( m_axi_awlock   ),
            .mst_aw_cache_o  ( m_axi_awcache  ),
            .mst_aw_qos_o    ( m_axi_awqos    ),
            .mst_aw_id_o     ( m_axi_awid     ),
            .mst_aw_user_o   ( m_axi_awuser   ),
            .mst_aw_ready_i  ( m_axi_awready  ),
            .mst_aw_valid_o  ( m_axi_awvalid  ),
            .mst_ar_addr_o   ( m_axi_araddr   ),
            .mst_ar_prot_o   ( m_axi_arprot   ),
            .mst_ar_region_o ( m_axi_arregion ),
            .mst_ar_len_o    ( m_axi_arlen    ),
            .mst_ar_size_o   ( m_axi_arsize   ),
            .mst_ar_burst_o  ( m_axi_arburst  ),
            .mst_ar_lock_o   ( m_axi_arlock   ),
            .mst_ar_cache_o  ( m_axi_arcache  ),
            .mst_ar_qos_o    ( m_axi_arqos    ),
            .mst_ar_id_o     ( m_axi_arid     ),
            .mst_ar_user_o   ( m_axi_aruser   ),
            .mst_ar_ready_i  ( m_axi_arready  ),
            .mst_ar_valid_o  ( m_axi_arvalid  ),
            .mst_w_data_o    ( m_axi_wdata    ),
            .mst_w_strb_o    ( m_axi_wstrb    ),
            .mst_w_user_o    ( m_axi_wuser    ),
            .mst_w_last_o    ( m_axi_wlast    ),
            .mst_w_ready_i   ( m_axi_wready   ),
            .mst_w_valid_o   ( m_axi_wvalid   ),
            .mst_r_data_i    ( m_axi_rdata    ),
            .mst_r_resp_i    ( m_axi_rresp    ),
            .mst_r_last_i    ( m_axi_rlast    ),
            .mst_r_id_i      ( m_axi_rid      ),
            .mst_r_user_i    ( m_axi_ruser    ),
            .mst_r_ready_o   ( m_axi_rready   ),
            .mst_r_valid_i   ( m_axi_rvalid   ),
            .mst_b_resp_i    ( m_axi_bresp    ),
            .mst_b_id_i      ( m_axi_bid      ),
            .mst_b_user_i    ( m_axi_buser    ),
            .mst_b_ready_o   ( m_axi_bready   ),
            .mst_b_valid_i   ( m_axi_bvalid   )
        );

  end else begin : gen_direct_axi_map

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

  end
endgenerate

endmodule : custom_top_wrapper