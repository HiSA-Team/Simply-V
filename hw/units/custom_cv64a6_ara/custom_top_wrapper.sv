// Author:  Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
//  Top wrapper integrating CVA6, Ara, AXI invalidation filter and AXI data width converter for Ara.
//  The IP features two 64-bit AXI master interfaces, one for CVA6, one for Ara.


// Import UninaSoC headers
`include "uninasoc_axi.svh"
`include "uninasoc_mem.svh"

// Import PULP headers
`include "typedef.svh" // axi/typedef.svh
`include "intf_typedef.svh" // ara/intf_typedef.svh

// Import CVA6 configuration package
// import config_pkg::*;
// import cva6_config_pkg::*;

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
    parameter LOCAL_AXI_USER_WIDTH    = 64,

    // Ara
    parameter ARA_NR_LANES = 2

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

    ////////////////////////////
    //  Bus Array Interfaces  //
    ////////////////////////////

    // AXI Master Interface Array
    `DEFINE_AXI_MASTER_PORTS(cva6, LOCAL_AXI_DATA_WIDTH, LOCAL_AXI_ADDR_WIDTH, LOCAL_AXI_ID_WIDTH),

    // AXI Master Interface Array
    `DEFINE_AXI_MASTER_PORTS(ara_axi_narrow, LOCAL_AXI_DATA_WIDTH, LOCAL_AXI_ADDR_WIDTH, LOCAL_AXI_ID_WIDTH)
);

    // Architecture:
    //   ______________
    //  |              |                                cva6_axi
    //  |     CVA6     |------------------------------------------->
    //  |______________|                                  d64
    //      ^
    //      | acc_resp_pack
    //      |\---------------------------------\
    //      |                                  |
    //      |                                  |
    //      |                                  |
    //      |                                  |
    //      | acc_resp                         | acc_cons_en
    //      | CVXIF                            | inval_addr/valid/ready
    //      | (w/ MMU)                   ______v____________
    //   ___v_____                      |                   |                       _____________
    //  |         |    ara_axi_wide     | L1D$ Invalidation |  ara_axi_wide_inval  |             | ara_axi_narrow
    //  |   Ara   |-------------------->|       Filter      |--------------------->| dwidth_conv | ----------->
    //  |_________|    d(32*NrLanes)    |___________________|     d(32*NrLanes)    |_____________|   d64
    //

    ///////////////
    // Constants //
    ///////////////

    // Default Ara AXI data width and VLEN
    // NOTE: These are fixed w.r.t. the number of lanes!
    localparam int unsigned AraWideDataWidth =   32 * ARA_NR_LANES;
    localparam int unsigned AraVLEN          = 1024 * ARA_NR_LANES;
    // Interconnect parameters
    localparam int unsigned DwidthConvAxiMaxReads = 4; // TODO: Tune this w.r.t. ARA_NR_LANES
    localparam int unsigned InvalFilterMaxTxns    = 4; // TODO: Tune this w.r.t. ARA_NR_LANES
    // OS support
    localparam int unsigned AraOSSupport          = 1;

    //////////////
    // Typedefs //
    //////////////

    // Baseline noc_req_t for narrow bus
    `AXI_TYPEDEF_ALL(
        axi,
        logic [LOCAL_AXI_ADDR_WIDTH -1 : 0],
        logic [LOCAL_AXI_ID_WIDTH   -1 : 0],
        logic [LOCAL_AXI_DATA_WIDTH -1 : 0],
        logic [LOCAL_AXI_STRB_WIDTH -1 : 0],
        logic [LOCAL_AXI_USER_WIDTH -1 : 0]  // This is for the user field, which is missing from our interface (or unused)
    )

    // Ara wide bus definition
    `AXI_TYPEDEF_ALL(
        ara_axi_wide,                        // name
        logic [LOCAL_AXI_ADDR_WIDTH -1 : 0], // address
        logic [LOCAL_AXI_ID_WIDTH   -1 : 0], // id
        logic [AraWideDataWidth     -1 : 0], // data
        logic [AraWideDataWidth/8   -1 : 0], // strb
        logic [LOCAL_AXI_USER_WIDTH -1 : 0]  // user
    )

    // From ara_soc.sv
    // Build CVA6's config
    localparam config_pkg::cva6_cfg_t CVA6AraConfig = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg);

    // Accelerator interface
    // Define the exception type
    `CVA6_TYPEDEF_EXCEPTION(exception_t, CVA6AraConfig);
    // Standard interface
    `CVA6_INTF_TYPEDEF_ACC_REQ(accelerator_req_t, CVA6AraConfig, fpnew_pkg::roundmode_e);
    `CVA6_INTF_TYPEDEF_ACC_RESP(accelerator_resp_t, CVA6AraConfig, exception_t);
    // MMU interface
    `CVA6_INTF_TYPEDEF_MMU_REQ(acc_mmu_req_t, CVA6AraConfig);
    `CVA6_INTF_TYPEDEF_MMU_RESP(acc_mmu_resp_t, CVA6AraConfig, exception_t);
    // Accelerator - CVA6's top-level interface
    `CVA6_INTF_TYPEDEF_CVA6_TO_ACC(cva6_to_acc_t, accelerator_req_t, acc_mmu_resp_t);
    `CVA6_INTF_TYPEDEF_ACC_TO_CVA6(acc_to_cva6_t, accelerator_resp_t, acc_mmu_req_t);

    /////////////////////////
    // AXI buses and ports //
    /////////////////////////

    // Narrow 64-bits
    axi_req_t  cva6_axi_req, ara_axi_narrow_req;
    axi_resp_t cva6_axi_resp, ara_axi_narrow_resp;
    // Wide Ara ports
    ara_axi_wide_req_t  ara_axi_wide_inval_req, ara_axi_wide_req;
    ara_axi_wide_resp_t ara_axi_wide_inval_resp, ara_axi_wide_resp;

    // Accelerator ports
    cva6_to_acc_t acc_req;
    acc_to_cva6_t acc_resp;

    // CVA6-Ara memory consistency
    logic                            acc_cons_en;
    logic [LOCAL_AXI_ADDR_WIDTH-1:0] inval_addr;
    logic                            inval_valid;
    logic                            inval_ready;

    // Pack invalidation interface into acc interface
    acc_to_cva6_t acc_resp_pack;
    always_comb begin : pack_inval
        // Pack
        acc_resp_pack                      = acc_resp;
        acc_resp_pack.acc_resp.inval_valid = inval_valid;
        acc_resp_pack.acc_resp.inval_addr  = inval_addr;
        // Unpack
        inval_ready                        = acc_req.acc_req.inval_ready;
        acc_cons_en                        = acc_req.acc_req.acc_cons_en;
    end : pack_inval

    /////////////
    // Modules //
    /////////////

    // CVA6
    cva6 #(
        .CVA6Cfg            ( CVA6AraConfig      ),
        .axi_ar_chan_t      ( axi_ar_chan_t      ),
        .axi_aw_chan_t      ( axi_aw_chan_t      ),
        .axi_w_chan_t       ( axi_w_chan_t       ),
        .b_chan_t           ( axi_b_chan_t       ),
        .r_chan_t           ( axi_r_chan_t       ),
        .cvxif_req_t        ( cva6_to_acc_t      ),
        .cvxif_resp_t       ( acc_to_cva6_t      ),
        .noc_req_t          ( axi_req_t          ),
        .noc_resp_t         ( axi_resp_t         ),
        .accelerator_req_t  ( accelerator_req_t  ),
        .accelerator_resp_t ( accelerator_resp_t ),
        .acc_mmu_req_t      ( acc_mmu_req_t      ),
        .acc_mmu_resp_t     ( acc_mmu_resp_t     )
    ) cva6_u (
        .clk_i            ( clk_i          ),
        .rst_ni           ( rst_ni         ),
        .boot_addr_i      ( boot_addr_i    ),
        .hart_id_i        ( hart_id_i      ),
        // Interrupts
        .irq_i            ( irq_i          ),
        .ipi_i            ( ipi_i          ),
        .time_irq_i       ( time_irq_i     ),
        .debug_req_i      ( debug_req_i    ),
        // Clic interface
        .clic_irq_valid_i ( '0             ),
        .clic_irq_id_i    ( '0             ),
        .clic_irq_level_i ( '0             ),
        .clic_irq_priv_i  ( '0             ),
        .clic_irq_shv_i   ( '0             ),
        .clic_irq_ready_o (                ), // Open
        .clic_kill_req_i  ( '0             ),
        .clic_kill_ack_o  (                ), // Open
        // RVFI probes
        .rvfi_probes_o    (                ), // Open
        // Accelerator interface
        .cvxif_req_o      ( acc_req        ),
        .cvxif_resp_i     ( acc_resp_pack  ),
        // AXI master
        .noc_req_o        ( cva6_axi_req   ),
        .noc_resp_i       ( cva6_axi_resp  )
    );

    // Ara
    ara #(
        .NrLanes            ( ARA_NR_LANES           ),
        .VLEN               ( AraVLEN                ),
        .OSSupport          ( AraOSSupport           ),
        .CVA6Cfg            ( CVA6AraConfig          ),
        .exception_t        ( exception_t            ),
        .accelerator_req_t  ( accelerator_req_t      ),
        .accelerator_resp_t ( accelerator_resp_t     ),
        .acc_mmu_req_t      ( acc_mmu_req_t          ),
        .acc_mmu_resp_t     ( acc_mmu_resp_t         ),
        .cva6_to_acc_t      ( cva6_to_acc_t          ),
        .acc_to_cva6_t      ( acc_to_cva6_t          ),
        .AxiDataWidth       ( AraWideDataWidth       ),
        .AxiAddrWidth       ( LOCAL_AXI_ADDR_WIDTH   ),
        .axi_ar_t           ( ara_axi_wide_ar_chan_t ),
        .axi_r_t            ( ara_axi_wide_r_chan_t  ),
        .axi_aw_t           ( ara_axi_wide_aw_chan_t ),
        .axi_w_t            ( ara_axi_wide_w_chan_t  ),
        .axi_b_t            ( ara_axi_wide_b_chan_t  ),
        .axi_req_t          ( ara_axi_wide_req_t     ),
        .axi_resp_t         ( ara_axi_wide_resp_t    )
    ) ara_u (
        .clk_i           ( clk_i             ),
        .rst_ni          ( rst_ni            ),
        .scan_enable_i   ( 1'b0              ),
        .scan_data_i     ( 1'b0              ),
        .scan_data_o     ( /* Unused */      ),
        .acc_req_i       ( acc_req           ),
        .acc_resp_o      ( acc_resp          ),
        .axi_req_o       ( ara_axi_wide_req  ),
        .axi_resp_i      ( ara_axi_wide_resp )
    );

    // AXI invalidation filter (for CVA6 L1D$)
    axi_inval_filter #(
        .MaxTxns      ( InvalFilterMaxTxns                ),
        .AddrWidth    ( LOCAL_AXI_ADDR_WIDTH              ),
        .L1LineWidth  ( CVA6AraConfig.DCACHE_LINE_WIDTH/8 ), // This must match CVA6's config
        .aw_chan_t    ( ara_axi_wide_aw_chan_t            ),
        .req_t        ( ara_axi_wide_req_t                ),
        .resp_t       ( ara_axi_wide_resp_t               )
    ) ara_axi_inval_filter_u (
        .clk_i        ( clk_i                   ),
        .rst_ni       ( rst_ni                  ),
        .en_i         ( acc_cons_en             ),
        .slv_req_i    ( ara_axi_wide_req        ),
        .slv_resp_o   ( ara_axi_wide_resp       ),
        .mst_req_o    ( ara_axi_wide_inval_req  ),
        .mst_resp_i   ( ara_axi_wide_inval_resp ),
        .inval_addr_o ( inval_addr              ),
        .inval_valid_o( inval_valid             ),
        .inval_ready_i( inval_ready             )
    );

    // Convert from AraWideDataWidth (ara_axi_wide_inval) to LOCAL_AXI_DATA_WIDTH (ara_axi_narrow)
    axi_dw_converter #(
        .AxiSlvPortDataWidth ( AraWideDataWidth       ),
        .AxiMstPortDataWidth ( LOCAL_AXI_DATA_WIDTH   ),
        .AxiMaxReads         ( DwidthConvAxiMaxReads  ),
        .AxiAddrWidth        ( LOCAL_AXI_ADDR_WIDTH   ),
        .AxiIdWidth          ( LOCAL_AXI_ID_WIDTH     ),
        .aw_chan_t           ( ara_axi_wide_aw_chan_t ),
        .mst_w_chan_t        ( axi_w_chan_t           ),
        .slv_w_chan_t        ( ara_axi_wide_w_chan_t  ),
        .b_chan_t            ( ara_axi_wide_b_chan_t  ),
        .ar_chan_t           ( ara_axi_wide_ar_chan_t ),
        .mst_r_chan_t        ( axi_r_chan_t           ),
        .slv_r_chan_t        ( ara_axi_wide_r_chan_t  ),
        .axi_mst_req_t       ( axi_req_t              ),
        .axi_mst_resp_t      ( axi_resp_t             ),
        .axi_slv_req_t       ( ara_axi_wide_req_t     ),
        .axi_slv_resp_t      ( ara_axi_wide_resp_t    )
    ) ara_axi_dw_converter_u (
        .clk_i      ( clk_i                   ),
        .rst_ni     ( rst_ni                  ),
        .slv_req_i  ( ara_axi_wide_inval_req  ),
        .slv_resp_o ( ara_axi_wide_inval_resp ),
        .mst_req_o  ( ara_axi_narrow_req      ),
        .mst_resp_i ( ara_axi_narrow_resp     )
    );

    /////////////////////////////
    // Map master port signals //
    /////////////////////////////

    // CVA6
    // Outputs
    assign cva6_axi_awid      = cva6_axi_req.aw.id;
    assign cva6_axi_awaddr    = cva6_axi_req.aw.addr;
    assign cva6_axi_awlen     = cva6_axi_req.aw.len;
    assign cva6_axi_awsize    = cva6_axi_req.aw.size;
    assign cva6_axi_awburst   = cva6_axi_req.aw.burst;
    assign cva6_axi_awlock    = cva6_axi_req.aw.lock;
    assign cva6_axi_awcache   = cva6_axi_req.aw.cache;
    assign cva6_axi_awprot    = cva6_axi_req.aw.prot;
    assign cva6_axi_awqos     = cva6_axi_req.aw.qos;
    assign cva6_axi_awregion  = cva6_axi_req.aw.region;
    assign cva6_axi_awvalid   = cva6_axi_req.aw_valid;
    assign cva6_axi_wdata     = cva6_axi_req.w.data;
    assign cva6_axi_wstrb     = cva6_axi_req.w.strb;
    assign cva6_axi_wlast     = cva6_axi_req.w.last;
    assign cva6_axi_wvalid    = cva6_axi_req.w_valid;
    assign cva6_axi_bready    = cva6_axi_req.b_ready;
    assign cva6_ara_axiddr    = cva6_axi_req.ar.addr;
    assign cva6_axi_arlen     = cva6_axi_req.ar.len;
    assign cva6_axi_arsize    = cva6_axi_req.ar.size;
    assign cva6_axi_arburst   = cva6_axi_req.ar.burst;
    assign cva6_axi_arlock    = cva6_axi_req.ar.lock;
    assign cva6_axi_arcache   = cva6_axi_req.ar.cache;
    assign cva6_axi_arprot    = cva6_axi_req.ar.prot;
    assign cva6_axi_arqos     = cva6_axi_req.ar.qos;
    assign cva6_axi_arregion  = cva6_axi_req.ar.region;
    assign cva6_axi_arvalid   = cva6_axi_req.ar_valid;
    assign cva6_axi_rready    = cva6_axi_req.r_ready;
    assign cva6_axi_arid      = cva6_axi_req.ar.id;
    // Inputs
    assign cva6_axi_resp.aw_ready = cva6_axi_awready;
    assign cva6_axi_resp.w_ready  = cva6_axi_wready;
    assign cva6_axi_resp.b.id     = cva6_axi_bid;
    assign cva6_axi_resp.b.resp   = cva6_axi_bresp;
    assign cva6_axi_resp.b_valid  = cva6_axi_bvalid;
    assign cva6_axi_resp.ar_ready = cva6_axi_arready;
    assign cva6_axi_resp.r.id     = cva6_axi_rid;
    assign cva6_axi_resp.r.data   = cva6_axi_rdata;
    assign cva6_axi_resp.r.resp   = cva6_axi_rresp;
    assign cva6_axi_resp.r.last   = cva6_axi_rlast;
    assign cva6_axi_resp.r_valid  = cva6_axi_rvalid;

    // AraNarrow
    // Outputs
    assign ara_axi_narrow_axi_awid      = ara_axi_narrow_req.aw.id;
    assign ara_axi_narrow_axi_awaddr    = ara_axi_narrow_req.aw.addr;
    assign ara_axi_narrow_axi_awlen     = ara_axi_narrow_req.aw.len;
    assign ara_axi_narrow_axi_awsize    = ara_axi_narrow_req.aw.size;
    assign ara_axi_narrow_axi_awburst   = ara_axi_narrow_req.aw.burst;
    assign ara_axi_narrow_axi_awlock    = ara_axi_narrow_req.aw.lock;
    assign ara_axi_narrow_axi_awcache   = ara_axi_narrow_req.aw.cache;
    assign ara_axi_narrow_axi_awprot    = ara_axi_narrow_req.aw.prot;
    assign ara_axi_narrow_axi_awqos     = ara_axi_narrow_req.aw.qos;
    assign ara_axi_narrow_axi_awregion  = ara_axi_narrow_req.aw.region;
    assign ara_axi_narrow_axi_awvalid   = ara_axi_narrow_req.aw_valid;
    assign ara_axi_narrow_axi_wdata     = ara_axi_narrow_req.w.data;
    assign ara_axi_narrow_axi_wstrb     = ara_axi_narrow_req.w.strb;
    assign ara_axi_narrow_axi_wlast     = ara_axi_narrow_req.w.last;
    assign ara_axi_narrow_axi_wvalid    = ara_axi_narrow_req.w_valid;
    assign ara_axi_narrow_axi_bready    = ara_axi_narrow_req.b_ready;
    assign ara_axi_narrow_ara_axiddr    = ara_axi_narrow_req.ar.addr;
    assign ara_axi_narrow_axi_arlen     = ara_axi_narrow_req.ar.len;
    assign ara_axi_narrow_axi_arsize    = ara_axi_narrow_req.ar.size;
    assign ara_axi_narrow_axi_arburst   = ara_axi_narrow_req.ar.burst;
    assign ara_axi_narrow_axi_arlock    = ara_axi_narrow_req.ar.lock;
    assign ara_axi_narrow_axi_arcache   = ara_axi_narrow_req.ar.cache;
    assign ara_axi_narrow_axi_arprot    = ara_axi_narrow_req.ar.prot;
    assign ara_axi_narrow_axi_arqos     = ara_axi_narrow_req.ar.qos;
    assign ara_axi_narrow_axi_arregion  = ara_axi_narrow_req.ar.region;
    assign ara_axi_narrow_axi_arvalid   = ara_axi_narrow_req.ar_valid;
    assign ara_axi_narrow_axi_rready    = ara_axi_narrow_req.r_ready;
    assign ara_axi_narrow_axi_arid      = ara_axi_narrow_req.ar.id;
    // Inputs
    assign ara_axi_narrow_resp.aw_ready = ara_axi_narrow_axi_awready;
    assign ara_axi_narrow_resp.w_ready  = ara_axi_narrow_axi_wready;
    assign ara_axi_narrow_resp.b.id     = ara_axi_narrow_axi_bid;
    assign ara_axi_narrow_resp.b.resp   = ara_axi_narrow_axi_bresp;
    assign ara_axi_narrow_resp.b_valid  = ara_axi_narrow_axi_bvalid;
    assign ara_axi_narrow_resp.ar_ready = ara_axi_narrow_axi_arready;
    assign ara_axi_narrow_resp.r.id     = ara_axi_narrow_axi_rid;
    assign ara_axi_narrow_resp.r.data   = ara_axi_narrow_axi_rdata;
    assign ara_axi_narrow_resp.r.resp   = ara_axi_narrow_axi_rresp;
    assign ara_axi_narrow_resp.r.last   = ara_axi_narrow_axi_rlast;
    assign ara_axi_narrow_resp.r_valid  = ara_axi_narrow_axi_rvalid;

endmodule : custom_top_wrapper
