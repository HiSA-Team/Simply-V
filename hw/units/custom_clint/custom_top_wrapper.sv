// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description: Top level wrapper module for:
//              - Clock divider for real-time clock generation
//              - 32-bit PULP CLINT
//              - AXI to register_interface adapter


// Import headers
`include "simplyv_axi.svh"
`include "simplyv_mem.svh"
`include "axi_typedef.svh"
`include "register_interface_assign.svh"
`include "register_interface_typedef.svh"

import axi_pkg::*;

module custom_top_wrapper # (

    //////////////////////////////////////
    //  Add here IP-related parameters  //
    //////////////////////////////////////

    // TODO121: Automatically align with config
    // AXI-related paraamters
    parameter                           LOCAL_AXI_DATA_WIDTH   = 32,
    parameter                           LOCAL_AXI_ADDR_WIDTH   = 32,
    parameter                           LOCAL_AXI_STRB_WIDTH   = LOCAL_AXI_ADDR_WIDTH / 8,
    parameter                           LOCAL_AXI_ID_WIDTH     = 5,
    parameter                           LOCAL_AXI_USER_WIDTH   = 2,
    parameter                           LOCAL_AXI_REGION_WIDTH = 4,
    parameter                           LOCAL_AXI_LEN_WIDTH    = 8,
    parameter                           LOCAL_AXI_SIZE_WIDTH   = 3,
    parameter                           LOCAL_AXI_BURST_WIDTH  = 2,
    parameter                           LOCAL_AXI_LOCK_WIDTH   = 1,
    parameter                           LOCAL_AXI_CACHE_WIDTH  = 4,
    parameter                           LOCAL_AXI_PROT_WIDTH   = 3,
    parameter                           LOCAL_AXI_QOS_WIDTH    = 4,
    parameter                           LOCAL_AXI_VALID_WIDTH  = 1,
    parameter                           LOCAL_AXI_READY_WIDTH  = 1,
    parameter                           LOCAL_AXI_LAST_WIDTH   = 1,
    parameter                           LOCAL_AXI_RESP_WIDTH   = 2,

    // REG-related parameters
    parameter int unsigned              REG_DATA_WIDTH         = 32,
    parameter bit                       CUT_MEM_REQS           = 1'b0,
    parameter bit                       CUT_MEM_RSPS           = 1'b0,

    // Division factor for real-time clock (RTC)
    localparam int unsigned             RTC_CLOCK_DIVIDE = 20

) (

    ///////////////////////////////////
    //  Add here IP-related signals  //
    ///////////////////////////////////

    input  logic       clk_i,       // Input clock, also divided to generate RTC
    input  logic       rst_ni,      // Input resetn
    output logic       rtc_o,       // Output divided RTC

    // For CLINTCORES=1
    output logic [0:0] timer_irq_o, // Timer interrupts
    output logic [0:0] ipi_o,       // software interrupt (a.k.a inter-process-interrupt)

    ////////////////////////////
    //  Bus Array Interfaces  //
    ////////////////////////////

    // AXI Slave Interface
    `DEFINE_AXI_SLAVE_PORTS(s, LOCAL_AXI_DATA_WIDTH, LOCAL_AXI_ADDR_WIDTH, LOCAL_AXI_ID_WIDTH)
);

    ////////////////////////
    // Signals Definition //
    ////////////////////////

    // RTC to CLINT
    logic clint_rtc;

    // First, we need to redefine the pulp axi types and reg types.
    // Define the req_t and resp_t type using axi_typedef.svh macro
    `AXI_TYPEDEF_ALL(
        axi,
        logic [LOCAL_AXI_ADDR_WIDTH-1:0],
        logic [LOCAL_AXI_ID_WIDTH-1:0],
        logic [LOCAL_AXI_DATA_WIDTH-1:0],
        logic [LOCAL_AXI_STRB_WIDTH-1:0],
        logic [0:0]  // This is for the user field, which is missing from our interface (or unused)
    )
    // Define the req_t and resp_t type using reg_typedef.svh macro
    `REG_BUS_TYPEDEF_ALL(
        reg,
        logic [LOCAL_AXI_ADDR_WIDTH-1:0],
        logic [LOCAL_AXI_DATA_WIDTH-1:0],
        logic [LOCAL_AXI_STRB_WIDTH-1:0]
    )

    // Instantiate intermediate signals to connect the axi converter to the reg-based plic interface
    axi_req_t axi_req;
    axi_resp_t axi_rsp;
    reg_req_t reg_req;
    reg_rsp_t reg_rsp;

    /////////////////
    // Assignments //
    /////////////////

    // Also output RTC
    assign rtc_o = clint_rtc;

    ///////////////////////
    // Instantiate Units //
    ///////////////////////

    // RTC clock divider
    clk_int_div_static #(
        .DIV_VALUE             ( RTC_CLOCK_DIVIDE ),
        .ENABLE_CLOCK_IN_RESET ( 1'b1             )
    ) rtc_clk_div_u (
        .clk_i          ( clk_i     ),
        .rst_ni         ( rst_ni    ),
        .en_i           ( 1'b1      ),
        .test_mode_en_i ( 1'b0      ),
        .clk_o          ( clint_rtc )
    );

    // CLINT
    clint #(
        .reg_req_t ( reg_req_t ),
        .reg_rsp_t ( reg_rsp_t )
    ) clint_u (
       .clk_i       ( clk_i       ),    // Clock
       .rst_ni      ( rst_ni      ),    // Asynchronous reset active low
       .testmode_i  ( '0          ),
       .reg_req_i   ( reg_req     ),
       .reg_rsp_o   ( reg_rsp     ),
       .rtc_i       ( clint_rtc   ),    // Real-time clock in (usually 32.768 kHz)
       .timer_irq_o ( timer_irq_o ),    // Timer interrupts
       .ipi_o       ( ipi_o       )     // software interrupt (a.k.a inter-process-interrupt)
    );

    // AXI/reg converter
    axi_to_reg_v2 #(
        .AxiAddrWidth       ( LOCAL_AXI_ADDR_WIDTH          ),
        .AxiDataWidth       ( LOCAL_AXI_DATA_WIDTH          ),
        .AxiIdWidth         ( LOCAL_AXI_ID_WIDTH            ),
        .AxiUserWidth       ( LOCAL_AXI_USER_WIDTH          ),
        .RegDataWidth       ( REG_DATA_WIDTH                ),
        .CutMemReqs         ( CUT_MEM_REQS                  ),
        .CutMemRsps         ( CUT_MEM_RSPS                  ),
        .axi_req_t          ( axi_req_t                     ),
        .axi_rsp_t          ( axi_resp_t                    ),
        .reg_req_t          ( reg_req_t                     ),
        .reg_rsp_t          ( reg_rsp_t                     ),
        .id_t               ( logic[LOCAL_AXI_ID_WIDTH-1:0] )
    ) axi_to_reg_v2_u (
        .clk_i              ( clk_i    ),
        .rst_ni             ( rst_ni   ),
        .axi_req_i          ( axi_req  ),
        .axi_rsp_o          ( axi_rsp  ),
        .reg_req_o          ( reg_req  ),
        .reg_rsp_i          ( reg_rsp  ),
        .reg_id_o           (          ), // Open
        .busy_o             (          )  // Open
    );


    // Map input/output AXI port
    assign   axi_req.aw.id        = s_axi_awid;
    assign   axi_req.aw.addr      = s_axi_awaddr;
    assign   axi_req.aw.len       = s_axi_awlen;
    assign   axi_req.aw.size      = s_axi_awsize;
    assign   axi_req.aw.burst     = s_axi_awburst;
    assign   axi_req.aw.lock      = s_axi_awlock;
    assign   axi_req.aw.cache     = s_axi_awcache;
    assign   axi_req.aw.prot      = s_axi_awprot;
    assign   axi_req.aw.qos       = s_axi_awqos;
    assign   axi_req.aw.region    = s_axi_awregion;
    assign   axi_req.aw_valid     = s_axi_awvalid;
    assign   axi_req.w.data       = s_axi_wdata;
    assign   axi_req.w.strb       = s_axi_wstrb;
    assign   axi_req.w.last       = s_axi_wlast;
    assign   axi_req.w_valid      = s_axi_wvalid;
    assign   axi_req.b_ready      = s_axi_bready;
    assign   axi_req.ar.addr      = s_axi_araddr;
    assign   axi_req.ar.len       = s_axi_arlen;
    assign   axi_req.ar.size      = s_axi_arsize;
    assign   axi_req.ar.burst     = s_axi_arburst;
    assign   axi_req.ar.lock      = s_axi_arlock;
    assign   axi_req.ar.cache     = s_axi_arcache;
    assign   axi_req.ar.prot      = s_axi_arprot;
    assign   axi_req.ar.qos       = s_axi_arqos;
    assign   axi_req.ar.region    = s_axi_arregion;
    assign   axi_req.ar_valid     = s_axi_arvalid;
    assign   axi_req.r_ready      = s_axi_rready;
    assign   axi_req.ar.id        = s_axi_arid;

    assign   s_axi_awready        = axi_rsp.aw_ready;
    assign   s_axi_wready         = axi_rsp.w_ready;
    assign   s_axi_bid            = axi_rsp.b.id;
    assign   s_axi_bresp          = axi_rsp.b.resp;
    assign   s_axi_bvalid         = axi_rsp.b_valid;
    assign   s_axi_arready        = axi_rsp.ar_ready;
    assign   s_axi_rid            = axi_rsp.r.id;
    assign   s_axi_rdata          = axi_rsp.r.data;
    assign   s_axi_rresp          = axi_rsp.r.resp;
    assign   s_axi_rlast          = axi_rsp.r.last;
    assign   s_axi_rvalid         = axi_rsp.r_valid;

endmodule : custom_top_wrapper
