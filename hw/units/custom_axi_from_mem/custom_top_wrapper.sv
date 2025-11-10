// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Description: Top level wrapper module for PULP AXI axi_from_mem adapter.


// Import headers
`include "uninasoc_axi.svh"
`include "uninasoc_mem.svh"
`include "typedef.svh"

module custom_top_wrapper # (

    //////////////////////////////////////
    //  Add here IP-related parameters  //
    //////////////////////////////////////

    // TODO121: Automatically align with config
    parameter LOCAL_MEM_ADDR_WIDTH    = 32,
    parameter LOCAL_MEM_DATA_WIDTH    = 32,
    parameter LOCAL_AXI_DATA_WIDTH    = 32,
    parameter LOCAL_AXI_ADDR_WIDTH    = 32,
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
    parameter LOCAL_AXI_RESP_WIDTH    = 2

) (

    ///////////////////////////////////
    //  Add here IP-related signals  //
    ///////////////////////////////////

    input  logic    clk_i,
    input  logic    rst_ni,

    ////////////////////////////
    //  Bus Array Interfaces  //
    ////////////////////////////

    // AXI4 Full Master interface from SRAM protocol (mem)
    `DEFINE_AXI_MASTER_PORTS (m, LOCAL_AXI_DATA_WIDTH, LOCAL_AXI_ADDR_WIDTH, LOCAL_AXI_ID_WIDTH),
    // Mem interface
    `DEFINE_MEM_SLAVE_PORTS  (s, LOCAL_MEM_DATA_WIDTH, LOCAL_MEM_ADDR_WIDTH)
);

    // Define the req_t and resp_t type using typedef.svh macro
    `AXI_TYPEDEF_ALL(
        axi,
        logic [LOCAL_AXI_ADDR_WIDTH-1:0],
        logic [LOCAL_AXI_ID_WIDTH-1:0],
        logic [LOCAL_AXI_DATA_WIDTH-1:0],
        logic [LOCAL_AXI_STRB_WIDTH-1:0],
        logic [0:0]  // This is for the user field, which is missing from our interface (or unused)
    )

    axi_req_t axi_req;
    axi_resp_t axi_rsp;

    // Define internal Cache signals (just a passthrough for clarity)
    logic [LOCAL_AXI_CACHE_WIDTH  -1 : 0] slv_aw_cache;
    logic [LOCAL_AXI_CACHE_WIDTH  -1 : 0] slv_ar_cache;


    // Instantiation of axi_from_mem module
    axi_from_mem #(
        .MemAddrWidth   ( LOCAL_MEM_ADDR_WIDTH ),        // Memory request address width
        .AxiAddrWidth   ( LOCAL_AXI_ADDR_WIDTH ),        // AXI4-Lite address width
        .DataWidth      ( LOCAL_AXI_DATA_WIDTH ),        // Data width of memory and AXI4-Lite
        .MaxRequests    ( 1                    ),        // Max number of in-flight requests
        .AxiProt        ( 3'b000               ),        // Protection signal for AXI4 transactions
        .axi_req_t      ( axi_req_t            ),        // AXI4 request struct type
        .axi_rsp_t      ( axi_resp_t           )         // AXI4 response struct type
    ) axi_from_mem_u (
        // Clock and Reset
        .clk_i          ( clk_i         ),
        .rst_ni         ( rst_ni        ),

        // Memory Slave Port Inputs
        .mem_req_i      ( s_mem_req     ),
        .mem_addr_i     ( s_mem_addr    ),
        .mem_we_i       ( s_mem_we      ),
        .mem_wdata_i    ( s_mem_wdata   ),
        .mem_be_i       ( s_mem_be      ),

        // Memory Slave Port Outputs
        .mem_gnt_o       ( s_mem_gnt    ),
        .mem_rsp_valid_o ( s_mem_valid  ),
        .mem_rsp_rdata_o ( s_mem_rdata  ),
        .mem_rsp_error_o ( s_mem_error  ),

        // AXI4 Master Port Inputs
        .slv_aw_cache_i ( slv_aw_cache  ),
        .slv_ar_cache_i ( slv_ar_cache  ),

        // AXI4 Master Port Outputs
        .axi_req_o      ( axi_req       ),

        // AXI4 Master Port Inputs
        .axi_rsp_i      ( axi_rsp       )
    );

    // Unwrap axi_from_mem structured type

    // Map Cache signals
    assign slv_aw_cache = m_axi_awcache;
    assign slv_ar_cache = m_axi_arcache;

    // Map OUTPUT signals
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


