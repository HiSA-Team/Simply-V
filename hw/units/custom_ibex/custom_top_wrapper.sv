// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Description:
//      Ibex CPU is fully functional in 3 configurations: LIGHTWEIGHT, PERFORMANCE and OPENTITAN
//      By Default, PERFORMANCE configuration is slected. Uncomment the appropriate define to select.
//      Currently OPENTITAN configuration works, but without the debugger


// Import headers
`include "uninasoc_axi.svh"
`include "uninasoc_mem.svh"

/////////////////////////
// Ibex Configurations //
/////////////////////////
//`define IBEX_LIGHTWEIGHT
`define IBEX_PERFORMANCE
//`define IBEX_OPENTITAN // Does not support debugger

module custom_top_wrapper import ibex_pkg::*; # (

    //////////////////////////////////////
    //  Add here IP-related parameters  //
    //////////////////////////////////////


    // TODO121: Automatically align with config
    // AXI/MEM macros parameter
    parameter LOCAL_DATA_WIDTH  = 32,
    parameter LOCAL_ADDR_WIDTH  = 32,

    // Debug-related Parameters
    parameter unsigned DmBaseAddr = 32'h00010800,
    parameter unsigned DmAddrMask = 32'h00000FFF,
    parameter unsigned DmHaltAddr = 32'h00010800,
    parameter unsigned DmExceptionAddr = DmHaltAddr + 32'h10

) (

    ///////////////////////////////////
    //  Add here IP-related signals  //
    ///////////////////////////////////

    // Clock and Reset
    input  logic                         clk_i,
    input  logic                         rst_ni,

    input  logic [31:0]                  hart_id_i,
    input  logic [31:0]                  boot_addr_i,

    // Interrupt inputs
    input  logic                         irq_software_i,
    input  logic                         irq_timer_i,
    input  logic                         irq_external_i,
    input  logic [14:0]                  irq_fast_i,
    input  logic                         irq_nm_i,       // non-maskable interrupt

    // Debug Interface
    input  logic                         debug_req_i,

    ////////////////////////////
    //  Bus Array Interfaces  //
    ////////////////////////////

    // MEM Master Interface Array
    `DEFINE_MEM_MASTER_PORTS(instr, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH),
    // MEM Slave Interface Array
    `DEFINE_MEM_MASTER_PORTS(data, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH)
);

    ibex_top #(

    `ifdef IBEX_LIGHTWEIGHT

        ///////////////////////
        // Ibex small config //
        ///////////////////////

        .RV32E              ( 1'b0 ),
        .RV32M              ( RV32MFast ),
        .RV32B              ( RV32BNone ),
        .RegFile            ( ibex_pkg::RegFileFPGA ),
        .BranchTargetALU    ( 0 ),
        .WritebackStage     ( 0 ),
        .ICache             ( 0 ),
        .ICacheECC          ( 0 ),
        .ICacheScramble     ( 0 ),
        .BranchPredictor    ( 0 ),
        .DbgTriggerEn       ( 0 ),
        .SecureIbex         ( 0 ),
        .PMPEnable          ( 0 ),
        .PMPGranularity     ( 0 ),
        .PMPNumRegions      ( 4 ),
        .MHPMCounterNum     ( 0 ),
        .MHPMCounterWidth   ( 40 ),

    `elsif IBEX_PERFORMANCE

        /////////////////////////////
        // Ibex Performance config //
        /////////////////////////////

        .RV32E              ( 0 ),
        .RV32M              ( ibex_pkg::RV32MSingleCycle ),
        .RV32B              ( ibex_pkg::RV32BBalanced ),
        .RegFile            ( ibex_pkg::RegFileFPGA ),
        .BranchTargetALU    ( 1 ),
        .WritebackStage     ( 1 ),
        .ICache             ( 0 ),
        .ICacheECC          ( 0 ),
        .ICacheScramble     ( 0 ),
        .BranchPredictor    ( 0 ),
        .DbgTriggerEn       ( 0 ),
        .SecureIbex         ( 0 ),
        .PMPEnable          ( 1 ),
        .PMPGranularity     ( 0 ),
        .PMPNumRegions      ( 16 ),
        .MHPMCounterNum     ( 0 ),
        .MHPMCounterWidth   ( 40 ),

    `elsif IBEX_OPENTITAN

        ///////////////////////////
        // Ibex OpenTitan config //
        ///////////////////////////
        // NOTE: Currently, this config does not support Debug Transport Module

        .RV32E              ( 0 ),
        .RV32M              ( ibex_pkg::RV32MSingleCycle ),
        .RV32B              ( ibex_pkg::RV32BOTEarlGrey ),
        .RegFile            ( ibex_pkg::RegFileFPGA ),
        .BranchTargetALU    ( 1 ),
        .WritebackStage     ( 1 ),
        .ICache             ( 1 ),
        .ICacheECC          ( 1 ),
        .ICacheScramble     ( 1 ),
        .BranchPredictor    ( 0 ),
        .DbgTriggerEn       ( 1 ),
        .SecureIbex         ( 1 ),
        .PMPEnable          ( 1 ),
        .PMPGranularity     ( 0 ),
        .PMPNumRegions      ( 16 ),
        .MHPMCounterNum     ( 10 ),
        .MHPMCounterWidth   ( 32 ),

    `endif

        //////////////////////
        // Debug Parameters //
        //////////////////////

        .DmBaseAddr         ( DmBaseAddr        ),
        .DmAddrMask         ( DmAddrMask        ),
        .DmHaltAddr         ( DmHaltAddr        ),
        .DmExceptionAddr    ( DmExceptionAddr   )

    ) ibex_u (
        // Clock and Reset
        .clk_i                  ( clk_i ),
        .rst_ni                 ( rst_ni ),

        .test_en_i              ( 1'b0 ),
        .scan_rst_ni            ( 1'b1 ),
        .ram_cfg_i              ( '0 ),

        .hart_id_i              ( hart_id_i ),
        // First instruction executed is going to be at boot_addr_i + 0x80 (i.e. right after the vector table)
        .boot_addr_i            ( boot_addr_i ),

        // Instruction memory interface
        .instr_req_o            ( instr_mem_req         ),
        .instr_gnt_i            ( instr_mem_gnt         ),
        .instr_rvalid_i         ( instr_mem_valid       ),
        .instr_addr_o           ( instr_mem_addr        ),
        .instr_rdata_i          ( instr_mem_rdata       ),
        .instr_rdata_intg_i     ( '0 ),
        .instr_err_i            ( '0 ),

        // Data memory interface
        .data_req_o             ( data_mem_req          ),
        .data_gnt_i             ( data_mem_gnt          ),
        .data_rvalid_i          ( data_mem_valid        ),
        .data_we_o              ( data_mem_we           ),
        .data_be_o              ( data_mem_be           ),
        .data_addr_o            ( data_mem_addr         ),
        .data_wdata_o           ( data_mem_wdata        ),
        .data_rdata_i           ( data_mem_rdata        ),
        .data_wdata_intg_o      ( ),
        .data_rdata_intg_i      ( '0 ),
        .data_err_i             ( '0 ),

        .irq_software_i         ( irq_software_i ),
        .irq_timer_i            ( irq_timer_i ),
        .irq_external_i         ( irq_external_i ),
        .irq_fast_i             ( irq_fast_i ),
        .irq_nm_i               ( irq_nm_i ),

        .scramble_key_valid_i   ('0 ),
        .scramble_key_i         ('0 ),
        .scramble_nonce_i       ('0 ),
        .scramble_req_o         ( ),

        .debug_req_i            ( debug_req_i ),
        .crash_dump_o           ( ),
        .double_fault_seen_o    ( ),

        .fetch_enable_i         ( ibex_pkg::IbexMuBiOn ),
        .alert_minor_o          ( ),
        .alert_major_internal_o ( ),
        .alert_major_bus_o      ( ),
        .core_sleep_o           ( )
    );


    // Tie-off non-driven signals
    assign instr_mem_wdata = '0;
    assign instr_mem_we    = '0;
    assign instr_mem_be    = '0;


endmodule : custom_top_wrapper


