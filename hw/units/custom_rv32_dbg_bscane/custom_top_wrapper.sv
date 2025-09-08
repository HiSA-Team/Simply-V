// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
// This module is intended as a top-level wrapper for the code in ./rtl
// IT might support either MEM protocol or AXI protocol, using the
// uninasoc_axi and uninasoc_mem svh files in hw/xilinx/rtl


// Import UninaSoC headers
`include "uninasoc_axi.svh"
`include "uninasoc_mem.svh"
// From axi/include
`include "typedef.svh"

module custom_top_wrapper # (

    //////////////////////////////////////
    //  Add here IP-related parameters  //
    //////////////////////////////////////
    parameter int unsigned        NrHarts          = 1,
    // parameter int unsigned        BusWidth         = 32,
    parameter logic [31:0]        DmBaseAddress    = 32'h10000, // TODO121: match from config
    // parameter int unsigned        DmBaseAddress    = 'h1000, // default to non-zero page
    // Bitmask to select physically available harts for systems
    // that don't use hart numbers in a contiguous fashion.
    parameter logic [NrHarts-1:0] SelectableHarts  = {NrHarts{1'b1}},
    // toggle new behavior to drive master_be_o during a read
    parameter bit                 ReadByteEnable   = 1,


    //////////////////////////////////////
    //  Add here IP-related parameters  //
    //////////////////////////////////////

    // TODO121: Automatically align with config
    parameter LOCAL_MEM_DATA_WIDTH    = 32,
    parameter LOCAL_MEM_ADDR_WIDTH    = 32,

    parameter LOCAL_AXI_DATA_WIDTH    = 32,
    parameter LOCAL_AXI_ADDR_WIDTH    = 32,
    parameter LOCAL_AXI_STRB_WIDTH    = 4,
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

    ///////////////////////
    // IP-related ports  //
    ///////////////////////

    input  logic                  clk_i,            // clock
    input  logic                  rst_ni,           // System reset
    // input  logic                  debug_reset_ni,   // Power-on-reset, not the system reset
    output logic                  ndmreset_o,       // non-debug module reset
    output logic                  dmactive_o,       // debug module is active
    output logic [NrHarts-1:0]    debug_req_o,      // async debug request
    input  logic [NrHarts-1:0]    unavailable_i,    // communicate whether the hart is unavailable (e.g.: power down)

    //////////////////////
    //  Bus Interfaces  //
    //////////////////////
    `DEFINE_AXI_MASTER_PORTS(dbg_master, LOCAL_AXI_DATA_WIDTH, LOCAL_AXI_ADDR_WIDTH, LOCAL_AXI_ID_WIDTH),
    `DEFINE_AXI_SLAVE_PORTS(dbg_slave, LOCAL_AXI_DATA_WIDTH, LOCAL_AXI_ADDR_WIDTH, LOCAL_AXI_ID_WIDTH)
);

    // Architecture:
    //   __________              _________________
    //  | (bscane) |            |                 |
    //  | dmi_jtag | -- DMI --> |      dm_top     | -- debug_req_o -->
    //  |__________|            |_________________|
    //                            |              ^
    //                            v              |
    //                       MEM master      MEM slave
    //                            |              ^
    //                     _______v______   _____|______
    //                    |              | |            |
    //                    | axi_from_mem | | axi_to_mem |
    //                    |______________| |____________|
    //                            |              ^
    //                            v              |
    //                       AXI master      AXI slave
    //

    ///////////////////
    // Local signals //
    ///////////////////

    // Define the req_t and resp_t type using typedef.svh macro
    `AXI_TYPEDEF_ALL(
        axi,
        logic [LOCAL_AXI_ADDR_WIDTH -1:0],
        logic [LOCAL_AXI_ID_WIDTH   -1:0],
        logic [LOCAL_AXI_DATA_WIDTH -1:0],
        logic [LOCAL_AXI_STRB_WIDTH -1:0],
        logic [0:0]  // This is for the user field, which is missing from our interface (or unused)
    )

    // AXI request/response structs
    axi_req_t  dbg_slave_axi_req;
    axi_resp_t dbg_slave_axi_resp;
    axi_req_t  dbg_master_axi_req;
    axi_resp_t dbg_master_axi_resp;

    // Mem buses
    `DECLARE_MEM_BUS(dbg_slave, LOCAL_MEM_DATA_WIDTH, LOCAL_MEM_ADDR_WIDTH);
    `DECLARE_MEM_BUS(dbg_master, LOCAL_MEM_DATA_WIDTH, LOCAL_MEM_ADDR_WIDTH);

    // Pack hartinfo_t struct
    dm::hartinfo_t hartinfo;
    // From ariane_pkg::DebugHartInfo
    // Same as https://github.com/lowRISC/ibex-demo-system/blob/main/rtl/system/dm_top.sv
    assign hartinfo.zero1        = '0;
    assign hartinfo.nscratch     = 2;  // Debug module needs at least two scratch regs
    assign hartinfo.zero0        = '0;
    assign hartinfo.dataaccess   = 1'b1;  // data registers are memory mapped in the debugger
    assign hartinfo.datasize     = dm::DataCount;
    assign hartinfo.dataaddr     = dm::DataAddr;

    // DMI interface
    // DM package-specific structs
    dm::dmi_req_t   dmi_req;
    dm::dmi_resp_t  dmi_resp;
    // Valid/ready
    logic           dmi_req_ready  ;
    logic           dmi_req_valid  ;
    logic           dmi_resp_ready ;
    logic           dmi_resp_valid ;
    // Reset
    logic           dmi_rst_n;

    //////////////////
    // Debug Module //
    //////////////////

    // Tie-off unconnected signals
    assign dbg_slave_mem_gnt   = '0;
    assign dbg_slave_mem_error = '0;

    // Debug Module
    dm_top #(
        .NrHarts        ( NrHarts              ),
        .BusWidth       ( LOCAL_MEM_DATA_WIDTH ), // Must be the same as LOCAL_MEM_ADDR_WIDTH
        .DmBaseAddress  ( DmBaseAddress        )
    ) dm_top_u (
        .clk_i,
        .rst_ni,
        // Deug ports
        .testmode_i           ( '0                    ),
        .ndmreset_o           ( ndmreset_o            ),
        .dmactive_o           ( dmactive_o            ),
        .unavailable_i        ( unavailable_i         ),
        .hartinfo_i           ( hartinfo              ),
        // To RV core
        .debug_req_o          ( debug_req_o           ),
        // Slave mem
        .slave_req_i          ( dbg_slave_mem_req     ),
        .slave_we_i           ( dbg_slave_mem_we      ),
        .slave_addr_i         ( dbg_slave_mem_addr    ),
        .slave_be_i           ( dbg_slave_mem_be      ),
        .slave_wdata_i        ( dbg_slave_mem_wdata   ),
        .slave_rdata_o        ( dbg_slave_mem_rdata   ),
        // Master mem
        .master_req_o         ( dbg_master_mem_req    ),
        .master_add_o         ( dbg_master_mem_addr   ),
        .master_we_o          ( dbg_master_mem_we     ),
        .master_wdata_o       ( dbg_master_mem_wdata  ),
        .master_be_o          ( dbg_master_mem_be     ),
        .master_gnt_i         ( dbg_master_mem_gnt    ),
        .master_r_valid_i     ( dbg_master_mem_valid  ),
        .master_r_rdata_i     ( dbg_master_mem_rdata  ),
        .master_r_err_i       ( dbg_master_mem_error  ),
        .master_r_other_err_i ( 1'b0                  ),
        // From DTM
        .dmi_rst_ni           ( dmi_rst_n             ),
        .dmi_req_valid_i      ( dmi_req_valid         ),
        .dmi_req_ready_o      ( dmi_req_ready         ),
        .dmi_req_i            ( dmi_req               ),
        .dmi_resp_valid_o     ( dmi_resp_valid        ),
        .dmi_resp_ready_i     ( dmi_resp_ready        ),
        .dmi_resp_o           ( dmi_resp              )
    );

    // Debug Transport Module and JTAG interface
    dmi_jtag dtm_u (
        .clk_i,
        .rst_ni,
        // To DM
        .dmi_rst_no       ( dmi_rst_n      ),
        .dmi_req_o        ( dmi_req        ),
        .dmi_req_ready_i  ( dmi_req_ready  ),
        .dmi_req_valid_o  ( dmi_req_valid  ),
        .dmi_resp_i       ( dmi_resp       ),
        .dmi_resp_ready_o ( dmi_resp_ready ),
        .dmi_resp_valid_i ( dmi_resp_valid ),
        .testmode_i       ( '0             ), // Unused
        // From JTAG
        .tck_i            ( '0             ), // Unused
        .tms_i            ( '0             ), // Unused
        .trst_ni          ( '1             ), // Unused
        .td_i             ( '0             ), // Unused
        .td_o             (                ), // Open
        .tdo_oe_o         (                )  // Open
    );

    //////////////////
    // AXI adapters //
    //////////////////

    // From cheshire_soc.sv
    localparam int unsigned axi_to_mem_NumBanks = 1;
    localparam int unsigned axi_to_mem_BufDepth = 4;

    // AXI access to debug module
    // axi_to_mem_interleaved #(
    axi_to_mem #(
        .axi_req_t  ( axi_req_t             ),
        .axi_resp_t ( axi_resp_t            ),
        .AddrWidth  ( LOCAL_AXI_ADDR_WIDTH  ),
        .DataWidth  ( LOCAL_AXI_DATA_WIDTH  ),
        .IdWidth    ( LOCAL_AXI_ID_WIDTH    ),
        .NumBanks   ( axi_to_mem_NumBanks   ),
        .BufDepth   ( axi_to_mem_BufDepth   )
    ) axi_to_mem_u (
        .clk_i,
        .rst_ni,
        // .test_i       ( test_mode_i ), // only for axi_to_mem_interleaved
        .busy_o       ( busy_o               ), // Open
        .axi_req_i    ( dbg_slave_axi_req    ),
        .axi_resp_o   ( dbg_slave_axi_resp   ),
        .mem_req_o    ( dbg_slave_mem_req    ),
        .mem_gnt_i    ( dbg_slave_mem_req    ), // From cheshire_soc.sv
        .mem_addr_o   ( dbg_slave_mem_addr   ),
        .mem_wdata_o  ( dbg_slave_mem_wdata  ),
        .mem_strb_o   ( dbg_slave_mem_be     ),
        .mem_atop_o   ( mem_atop_o           ), // Open
        .mem_we_o     ( dbg_slave_mem_we     ),
        .mem_rvalid_i ( dbg_slave_mem_valid  ),
        .mem_rdata_i  ( dbg_slave_mem_rdata  )
    );

    // From cheshire_soc.sv
    // Read response is valid one cycle after request
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if ( !rst_ni ) begin
            dbg_slave_mem_valid <= '0;
        end
        else begin
            dbg_slave_mem_valid <= dbg_slave_mem_req;
        end
    end

    // From cheshire_pkg.sv
    localparam int unsigned     axi_from_mem_MaxRequests = 4;
    localparam axi_pkg::prot_t  axi_from_mem_AxiProt = 3'b000;

    // Debug module system bus access to AXI crossbar
    axi_from_mem #(
        .MemAddrWidth ( LOCAL_AXI_ADDR_WIDTH     ),
        .AxiAddrWidth ( LOCAL_AXI_ADDR_WIDTH     ),
        .DataWidth    ( LOCAL_AXI_DATA_WIDTH     ),
        .MaxRequests  ( axi_from_mem_MaxRequests ),
        .AxiProt      ( axi_from_mem_AxiProt     ),
        .axi_req_t    ( axi_req_t                ),
        .axi_rsp_t    ( axi_resp_t               )
    ) axi_from_mem_u (
        .clk_i,
        .rst_ni,
        .mem_req_i       ( dbg_master_mem_req    ),
        .mem_addr_i      ( dbg_master_mem_addr   ),
        .mem_we_i        ( dbg_master_mem_we     ),
        .mem_wdata_i     ( dbg_master_mem_wdata  ),
        .mem_be_i        ( dbg_master_mem_be     ),
        .mem_gnt_o       ( dbg_master_mem_gnt    ),
        .mem_rsp_valid_o ( dbg_master_mem_valid  ),
        .mem_rsp_rdata_o ( dbg_master_mem_rdata  ),
        .mem_rsp_error_o ( dbg_master_mem_error  ),
        .slv_aw_cache_i  ( axi_pkg::CACHE_MODIFIABLE ),
        .slv_ar_cache_i  ( axi_pkg::CACHE_MODIFIABLE ),
        .axi_req_o       ( dbg_master_axi_req    ),
        .axi_rsp_i       ( dbg_master_axi_resp   )
    );


    ////////////////////////////////
    // Unwrap axi structured type //
    ////////////////////////////////

    // AXI slave request
    assign dbg_slave_axi_req.aw.id        = dbg_slave_axi_awid;
    assign dbg_slave_axi_req.aw.addr      = dbg_slave_axi_awaddr;
    assign dbg_slave_axi_req.aw.len       = dbg_slave_axi_awlen;
    assign dbg_slave_axi_req.aw.size      = dbg_slave_axi_awsize;
    assign dbg_slave_axi_req.aw.burst     = dbg_slave_axi_awburst;
    assign dbg_slave_axi_req.aw.lock      = dbg_slave_axi_awlock;
    assign dbg_slave_axi_req.aw.cache     = dbg_slave_axi_awcache;
    assign dbg_slave_axi_req.aw.prot      = dbg_slave_axi_awprot;
    assign dbg_slave_axi_req.aw.qos       = dbg_slave_axi_awqos;
    assign dbg_slave_axi_req.aw.region    = dbg_slave_axi_awregion;
    assign dbg_slave_axi_req.aw_valid     = dbg_slave_axi_awvalid;
    assign dbg_slave_axi_req.w.data       = dbg_slave_axi_wdata;
    assign dbg_slave_axi_req.w.strb       = dbg_slave_axi_wstrb;
    assign dbg_slave_axi_req.w.last       = dbg_slave_axi_wlast;
    assign dbg_slave_axi_req.w_valid      = dbg_slave_axi_wvalid;
    assign dbg_slave_axi_req.b_ready      = dbg_slave_axi_bready;
    assign dbg_slave_axi_req.ar.addr      = dbg_slave_axi_araddr;
    assign dbg_slave_axi_req.ar.len       = dbg_slave_axi_arlen;
    assign dbg_slave_axi_req.ar.size      = dbg_slave_axi_arsize;
    assign dbg_slave_axi_req.ar.burst     = dbg_slave_axi_arburst;
    assign dbg_slave_axi_req.ar.lock      = dbg_slave_axi_arlock;
    assign dbg_slave_axi_req.ar.cache     = dbg_slave_axi_arcache;
    assign dbg_slave_axi_req.ar.prot      = dbg_slave_axi_arprot;
    assign dbg_slave_axi_req.ar.qos       = dbg_slave_axi_arqos;
    assign dbg_slave_axi_req.ar.region    = dbg_slave_axi_arregion;
    assign dbg_slave_axi_req.ar_valid     = dbg_slave_axi_arvalid;
    assign dbg_slave_axi_req.r_ready      = dbg_slave_axi_rready;
    assign dbg_slave_axi_req.ar.id        = dbg_slave_axi_arid;

    // AXI slave response
    assign dbg_slave_axi_awready        = dbg_slave_axi_resp.aw_ready ;
    assign dbg_slave_axi_wready         = dbg_slave_axi_resp.w_ready  ;
    assign dbg_slave_axi_bid            = dbg_slave_axi_resp.b.id     ;
    assign dbg_slave_axi_bresp          = dbg_slave_axi_resp.b.resp   ;
    assign dbg_slave_axi_bvalid         = dbg_slave_axi_resp.b_valid  ;
    assign dbg_slave_axi_arready        = dbg_slave_axi_resp.ar_ready ;
    assign dbg_slave_axi_rid            = dbg_slave_axi_resp.r.id     ;
    assign dbg_slave_axi_rdata          = dbg_slave_axi_resp.r.data   ;
    assign dbg_slave_axi_rresp          = dbg_slave_axi_resp.r.resp   ;
    assign dbg_slave_axi_rlast          = dbg_slave_axi_resp.r.last   ;
    assign dbg_slave_axi_rvalid         = dbg_slave_axi_resp.r_valid  ;

    // AXI master request
    assign dbg_master_axi_awid      = dbg_master_axi_req.aw.id;
    assign dbg_master_axi_awaddr    = dbg_master_axi_req.aw.addr;
    assign dbg_master_axi_awlen     = dbg_master_axi_req.aw.len;
    assign dbg_master_axi_awsize    = dbg_master_axi_req.aw.size;
    assign dbg_master_axi_awburst   = dbg_master_axi_req.aw.burst;
    assign dbg_master_axi_awlock    = dbg_master_axi_req.aw.lock;
    assign dbg_master_axi_awcache   = dbg_master_axi_req.aw.cache;
    assign dbg_master_axi_awprot    = dbg_master_axi_req.aw.prot;
    assign dbg_master_axi_awqos     = dbg_master_axi_req.aw.qos;
    assign dbg_master_axi_awregion  = dbg_master_axi_req.aw.region;
    assign dbg_master_axi_awvalid   = dbg_master_axi_req.aw_valid;
    assign dbg_master_axi_wdata     = dbg_master_axi_req.w.data;
    assign dbg_master_axi_wstrb     = dbg_master_axi_req.w.strb;
    assign dbg_master_axi_wlast     = dbg_master_axi_req.w.last;
    assign dbg_master_axi_wvalid    = dbg_master_axi_req.w_valid;
    assign dbg_master_axi_bready    = dbg_master_axi_req.b_ready;
    assign dbg_master_axi_araddr    = dbg_master_axi_req.ar.addr;
    assign dbg_master_axi_arlen     = dbg_master_axi_req.ar.len;
    assign dbg_master_axi_arsize    = dbg_master_axi_req.ar.size;
    assign dbg_master_axi_arburst   = dbg_master_axi_req.ar.burst;
    assign dbg_master_axi_arlock    = dbg_master_axi_req.ar.lock;
    assign dbg_master_axi_arcache   = dbg_master_axi_req.ar.cache;
    assign dbg_master_axi_arprot    = dbg_master_axi_req.ar.prot;
    assign dbg_master_axi_arqos     = dbg_master_axi_req.ar.qos;
    assign dbg_master_axi_arregion  = dbg_master_axi_req.ar.region;
    assign dbg_master_axi_arvalid   = dbg_master_axi_req.ar_valid;
    assign dbg_master_axi_rready    = dbg_master_axi_req.r_ready;
    assign dbg_master_axi_arid      = dbg_master_axi_req.ar.id;

    // AXI master response
    assign dbg_master_axi_resp.aw_ready = dbg_master_axi_awready;
    assign dbg_master_axi_resp.w_ready  = dbg_master_axi_wready;
    assign dbg_master_axi_resp.b.id     = dbg_master_axi_bid;
    assign dbg_master_axi_resp.b.resp   = dbg_master_axi_bresp;
    assign dbg_master_axi_resp.b_valid  = dbg_master_axi_bvalid;
    assign dbg_master_axi_resp.ar_ready = dbg_master_axi_arready;
    assign dbg_master_axi_resp.r.id     = dbg_master_axi_rid;
    assign dbg_master_axi_resp.r.data   = dbg_master_axi_rdata;
    assign dbg_master_axi_resp.r.resp   = dbg_master_axi_rresp;
    assign dbg_master_axi_resp.r.last   = dbg_master_axi_rlast;
    assign dbg_master_axi_resp.r_valid  = dbg_master_axi_rvalid;


endmodule : custom_top_wrapper


