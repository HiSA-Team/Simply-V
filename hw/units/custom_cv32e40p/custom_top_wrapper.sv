// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Description:
// This module is intended as a top-level wrapper for the code in ./rtl
// IT might support either MEM protocol or AXI protocol, using the
// uninasoc_axi and uninasoc_mem svh files in hw/xilinx/rtl


// Import headers
`include "uninasoc_axi.svh"
`include "uninasoc_mem.svh"

module custom_top_wrapper # (

    //////////////////////////////////////
    //  Add here IP-related parameters  //
    //////////////////////////////////////

    // TODO121: Automatically align with config
    parameter LOCAL_DATA_WIDTH  = 32,   // AXI/MEM macros parameter
    parameter LOCAL_ADDR_WIDTH  = 32,   // AXI/MEM macros parameter
    parameter COREV_PULP        = 0,    // PULP ISA Extension (incl. custom CSRs and hardware loop, excl. cv.elw)
    parameter COREV_CLUSTER     = 0,    // PULP Cluster interface (incl. cv.elw)
    parameter FPU               = 0,    // Floating Point Unit (interfaced via APU interface)
    parameter FPU_ADDMUL_LAT    = 0,    // Floating-Point ADDition/MULtiplication computing lane pipeline registers number
    parameter FPU_OTHERS_LAT    = 0,    // Floating-Point COMParison/CONVersion computing lanes pipeline registers number
    parameter ZFINX             = 0,    // Float-in-General Purpose registers
    parameter NUM_MHPMCOUNTERS  = 1

) (

    ///////////////////////////////////
    //  Add here IP-related signals  //
    ///////////////////////////////////

    input logic         clk_i,
    input logic         rst_ni,

    input logic         pulp_clock_en_i,    // PULP clock enable (only used if COREV_CLUSTER = 1)
    input logic         scan_cg_en_i,       // Enable all clock gates for testing

    // Core ID, Cluster ID, debug mode halt address and boot address are considered more or less static
    input logic [31:0]  boot_addr_i,
    input logic [31:0]  mtvec_addr_i,
    input logic [31:0]  dm_halt_addr_i,
    input logic [31:0]  hart_id_i,
    input logic [31:0]  dm_exception_addr_i,

    // Interrupt inputs
    input  logic [31:0] irq_i,              // CLINT interrupts + CLINT extension interrupts
    output logic        irq_ack_o,
    output logic [ 4:0] irq_id_o,

    // Debug Interface
    input  logic        debug_req_i,
    output logic        debug_havereset_o,
    output logic        debug_running_o,
    output logic        debug_halted_o,

    // CPU Control Signals
    input  logic        fetch_enable_i,
    output logic        core_sleep_o,

    ////////////////////////////
    //  Bus Array Interfaces  //
    ////////////////////////////

    // MEM Master Interface Array
    `DEFINE_MEM_MASTER_PORTS(instr, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH),
    // MEM Slave Interface Array
    `DEFINE_MEM_MASTER_PORTS(data, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH)
);

    // Tie-off non-driven signals
    assign instr_mem_wdata = '0;
    assign instr_mem_we    = '0;
    assign instr_mem_be    = '0;

    cv32e40p_top #(
        .COREV_PULP             ( COREV_PULP        ),  // PULP ISA Extension (incl. custom CSRs and hardware loop, excl. cv.elw)
        .COREV_CLUSTER          ( COREV_CLUSTER     ),  // PULP Cluster interface (incl. cv.elw)
        .FPU                    ( FPU               ),  // Floating Point Unit (interfaced via APU interface)
        .FPU_ADDMUL_LAT         ( FPU_ADDMUL_LAT    ),  // Floating-Point ADDition/MULtiplication computing lane pipeline registers number
        .FPU_OTHERS_LAT         ( FPU_OTHERS_LAT    ),  // Floating-Point COMParison/CONVersion computing lanes pipeline registers number
        .ZFINX                  ( ZFINX             ),  // Float-in-General Purpose registers
        .NUM_MHPMCOUNTERS       ( NUM_MHPMCOUNTERS  )
    ) (
        // Clock and Reset
        .clk_i                  ( clk_i               ),
        .rst_ni                 ( rst_ni              ),

        .pulp_clock_en_i        ( pulp_clock_en_i       ),  // PULP clock enable (only used if COREV_CLUSTER = 1)
        .scan_cg_en_i           ( scan_cg_en_i          ),  // Enable all clock gates for testing

        // Core ID, Cluster ID, debug mode halt address and boot address are considered more or less static
        .boot_addr_i            ( boot_addr_i           ),
        .mtvec_addr_i           ( mtvec_addr_i          ),
        .dm_halt_addr_i         ( dm_halt_addr_i        ),
        .hart_id_i              ( hart_id_i             ),
        .dm_exception_addr_i    ( dm_exception_addr_i   ),

        // Instruction memory interface
        .instr_req_o            ( instr_mem_req         ),
        .instr_gnt_i            ( instr_mem_gnt         ),
        .instr_rvalid_i         ( instr_mem_valid       ),
        .instr_addr_o           ( instr_mem_addr        ),
        .instr_rdata_i          ( instr_mem_rdata       ),

        // Data memory interface
        .data_req_o             ( data_mem_req          ),
        .data_gnt_i             ( data_mem_gnt          ),
        .data_rvalid_i          ( data_mem_valid        ),
        .data_we_o              ( data_mem_we           ),
        .data_be_o              ( data_mem_be           ),
        .data_addr_o            ( data_mem_addr         ),
        .data_wdata_o           ( data_mem_wdata        ),
        .data_rdata_i           ( data_mem_rdata        ),

        // Interrupt inputs
        .irq_i                  ( irq_i                 ),  // CLINT interrupts + CLINT extension interrupts
        .irq_ack_o              ( irq_ack_o             ),
        .irq_id_o               ( irq_id_o              ),

        // Debug Interface
        .debug_req_i            ( debug_req_i           ),
        .debug_havereset_o      ( debug_havereset_o     ),
        .debug_running_o        ( debug_running_o       ),
        .debug_halted_o         ( debug_halted_o        ),

        // CPU Control Signals
        .fetch_enable_i         ( fetch_enable_i        ),
        .core_sleep_o           ( core_sleep_o          )
    );

endmodule : custom_top_wrapper


