// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Author: Cesare Pulcrano <ce.pulcrano@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description: Wrapper module for RISC-V CPUs and Debuggers

// Import packages
import uninasoc_pkg::*;

// Import headers
`include "uninasoc_axi.svh"
`include "uninasoc_mem.svh"

module rv_socket # (
    parameter core_selector_t CORE_SELECTOR     = CORE_CV32E40P,
    parameter int unsigned    LOCAL_DATA_WIDTH  = 32,
    parameter int unsigned    LOCAL_ADDR_WIDTH  = 32,
    parameter int unsigned    LOCAL_ID_WIDTH    = 2,
    parameter int unsigned    NUM_IRQ           = 32
) (
    input  logic                            clk_i,
    input  logic                            rst_ni,        // System-wide reset (also resets core)
    input  logic                            core_resetn_i, // Core-only reset (does not reset DM and other modules)
    input  logic [LOCAL_ADDR_WIDTH -1 : 0 ] bootaddr_i,
    input  logic [NUM_IRQ          -1 : 0 ] irq_i,

    // Core
    `DEFINE_AXI_MASTER_PORTS(rv_socket_instr, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH),
    `DEFINE_AXI_MASTER_PORTS(rv_socket_data, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH),

    // Debug module
    `DEFINE_AXI_MASTER_PORTS(rv_socket_dbg_master, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH),
    `DEFINE_AXI_SLAVE_PORTS(rv_socket_dbg_slave, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)
);

    //////////////////////////////////////////////////////
    //    ___                         _                 //
    //   | _ \__ _ _ _ __ _ _ __  ___| |_ ___ _ _ ___   //
    //   |  _/ _` | '_/ _` | '  \/ -_)  _/ -_) '_(_-<   //
    //   |_| \__,_|_| \__,_|_|_|_\___|\__\___|_| /__/   //
    //                                                  //
    //////////////////////////////////////////////////////

    // Let's assume single core
    localparam logic [LOCAL_DATA_WIDTH-1:0] hart_id = '0;
    localparam logic [LOCAL_ADDR_WIDTH-1:0] DEBUG_START   = 'h10000; // From config

    // From dm_pkg
    localparam logic [LOCAL_ADDR_WIDTH-1:0] dm_HaltAddress = 'h800;
    localparam logic [LOCAL_ADDR_WIDTH-1:0] dm_ExceptionAddress = dm_HaltAddress + 16;

    //////////////////////////////////////
    //    ___ _                _        //
    //   / __(_)__ _ _ _  __ _| |___    //
    //   \__ | / _` | ' \/ _` | (_-<    //
    //   |___|_\__, |_||_\__,_|_/__/    //
    //         |___/                    //
    //////////////////////////////////////

    // Core reset
    logic core_resetn_internal;
    assign core_resetn_internal = rst_ni & core_resetn_i;

    // Declare AXI interfaces for instruction memory port and data memory port
    `DECLARE_AXI_BUS(core_instr_to_socket_instr, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH);
    `DECLARE_AXI_BUS(core_data_to_socket_data, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH);

    // Declare MEM ports
    `DECLARE_MEM_BUS(core_instr, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH);
    `DECLARE_MEM_BUS(core_data, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH);

    // Debug request DM -> RV core
    logic debug_req_core;

    //////////////////////////////////////////////////////
    //     ___               ___          _             //
    //    / __|___ _ _ ___  | _ \___ __ _(_)___ _ _     //
    //   | (__/ _ \ '_/ -_) |   / -_) _` | / _ \ ' \    //
    //    \___\___/_| \___| |_|_\___\__, |_\___/_||_|   //
    //                              |___/               //
    //////////////////////////////////////////////////////

    ////////////////////////////
    // Core validity checking //
    ////////////////////////////

    // Check if the selected Core is compatible with the system XLEN
    if ( LOCAL_DATA_WIDTH == 64 && CORE_SELECTOR inside {CORE_PICORV32,CORE_CV32E40P,CORE_IBEX,CORE_MICROBLAZEV_RV32} ||
         LOCAL_DATA_WIDTH == 32 && CORE_SELECTOR inside {CORE_CV64A6, CORE_MICROBLAZEV_RV64} ) begin : xlen_core_error
        $error($sformatf("[Socket] Illegal CORE (%s) for the selected XLEN (%0d)",
                        core_selector_to_string(CORE_SELECTOR), LOCAL_DATA_WIDTH));
    end : xlen_core_error

    ////////////////////////
    // Core Instantiation //
    ////////////////////////

    generate
        if (CORE_SELECTOR == CORE_PICORV32) begin: core_picorv32

            //////////////////////////
            //      PicoRV32        //
            //////////////////////////

            // Tie-off unused signals
            assign core_instr_mem_wdata = '0;
            assign core_instr_mem_we    = '0;
            assign core_instr_mem_be    = '0;

            ///////////////////////////////////////////////////////////////////////////
            //  Pico has a custom interrupt handling mechanisms. I am not sure if    //
            //  it is just an alternative to standard risc-v interrupt handling,     //
            //  or if it is incompatible. Therefore, beware of it and use Pico       //
            //  only for interrupt-less applications.                                //
            ///////////////////////////////////////////////////////////////////////////

            custom_picorv32 picorv32_core (
                .clk_i              ( clk_i                     ),
                .rst_ni             ( core_resetn_internal       ),
                .trap_o             (                           ),

                .instr_mem_req      ( core_instr_mem_req        ),
                .instr_mem_gnt      ( core_instr_mem_gnt        ),
                .instr_mem_valid    ( core_instr_mem_valid      ),
                .instr_mem_addr     ( core_instr_mem_addr       ),
                .instr_mem_rdata    ( core_instr_mem_rdata      ),
                .instr_mem_error    ( core_instr_mem_error      ), // Although unused

                .data_mem_req       ( core_data_mem_req         ),
                .data_mem_valid     ( core_data_mem_valid       ),
                .data_mem_gnt       ( core_data_mem_gnt         ),
                .data_mem_we        ( core_data_mem_we          ),
                .data_mem_be        ( core_data_mem_be          ),
                .data_mem_addr      ( core_data_mem_addr        ),
                .data_mem_wdata     ( core_data_mem_wdata       ),
                .data_mem_rdata     ( core_data_mem_rdata       ),
                .data_mem_error     ( core_data_mem_error       ), // Although unused

                .irq_i              ( irq_i                     ),

            `ifdef RISCV_FORMAL
                .rvfi_valid         (                           ),
                .rvfi_order         (                           ),
                .rvfi_insn          (                           ),
                .rvfi_trap          (                           ),
                .rvfi_halt          (                           ),
                .rvfi_intr          (                           ),
                .rvfi_rs1_addr      (                           ),
                .rvfi_rs2_addr      (                           ),
                .rvfi_rs1_rdata     (                           ),
                .rvfi_rs2_rdata     (                           ),
                .rvfi_rd_addr       (                           ),
                .rvfi_rd_wdata      (                           ),
                .rvfi_pc_rdata      (                           ),
                .rvfi_pc_wdata      (                           ),
                .rvfi_mem_addr      (                           ),
                .rvfi_mem_rmask     (                           ),
                .rvfi_mem_wmask     (                           ),
                .rvfi_mem_rdata     (                           ),
                .rvfi_mem_wdata     (                           ),
            `endif

                .trace_valid_o      (                           ), // Unmapped atm
                .trace_data_o       (                           )  // Unmapped atm
            );

        end
        else if (CORE_SELECTOR == CORE_CV32E40P) begin: core_cv32e40p

            //////////////////////////
            //      CV32E40P        //
            //////////////////////////

            custom_cv32e40p cv32e40p_core (
                // Clock and Reset
                .clk_i                  ( clk_i                     ),
                .rst_ni                 ( core_resetn_internal       ),

                .pulp_clock_en_i        ( '0                        ),  // PULP clock enable (only used if COREV_CLUSTER = 1)
                .scan_cg_en_i           ( '0                        ),  // Enable all clock gates for testing

                // Core ID, Cluster ID, debug mode halt address and boot address are considered more or less static
                .boot_addr_i            ( bootaddr_i                ),
                .hart_id_i              ( hart_id                   ),
                .mtvec_addr_i           ( '0                        ),  // TBD
                .dm_halt_addr_i         ( DEBUG_START + dm_HaltAddress[31:0]      ),  // TBD
                .dm_exception_addr_i    ( DEBUG_START + dm_ExceptionAddress[31:0] ),  // TBD

                // Instruction memory interface
                .instr_mem_req          ( core_instr_mem_req        ),
                .instr_mem_gnt          ( core_instr_mem_gnt        ),
                .instr_mem_valid        ( core_instr_mem_valid      ),
                .instr_mem_addr         ( core_instr_mem_addr       ),
                .instr_mem_be           ( core_instr_mem_be         ),
                .instr_mem_we           ( core_instr_mem_we         ),
                .instr_mem_wdata        ( core_instr_mem_wdata      ),
                .instr_mem_rdata        ( core_instr_mem_rdata      ),
                .instr_mem_error        ( core_instr_mem_error      ), // Although unused

                // Data memory interface
                .data_mem_req           ( core_data_mem_req         ),
                .data_mem_valid         ( core_data_mem_valid       ),
                .data_mem_gnt           ( core_data_mem_gnt         ),
                .data_mem_we            ( core_data_mem_we          ),
                .data_mem_be            ( core_data_mem_be          ),
                .data_mem_addr          ( core_data_mem_addr        ),
                .data_mem_wdata         ( core_data_mem_wdata       ),
                .data_mem_rdata         ( core_data_mem_rdata       ),
                .data_mem_error         ( core_data_mem_error       ), // Although unused

                // Interrupt inputs
                .irq_i                  ( irq_i                     ),  // CLINT interrupts + CLINT extension interrupts
                .irq_ack_o              (                           ),  // TBD
                .irq_id_o               (                           ),  // TBD

                // Debug Interface
                .debug_req_i            ( debug_req_core            ),  // From Debug Module
                .debug_havereset_o      ( debug_havereset_o         ),  // Open
                .debug_running_o        ( debug_running_o           ),  // Open
                .debug_halted_o         ( debug_halted_o            ),  // Open

                // CPU Control Signals
                .fetch_enable_i         ( 1'b1                      ),
                .core_sleep_o           (                           )   // TBD
            );

        end
        else if (CORE_SELECTOR == CORE_IBEX) begin : core_ibex

            //////////////////////
            //      Ibex        //
            //////////////////////

            custom_ibex ibex_core (
                // Clock and Reset
                .clk_i                  ( clk_i ),
                .rst_ni                 ( core_resetn_internal ),
                .hart_id_i              ( hart_id ),
                // First instruction executed is going to be at boot_addr_i + 0x80 (i.e. right after the vector table)
                .boot_addr_i            ( bootaddr_i ),

                // Instruction memory interface
                .instr_mem_req          ( core_instr_mem_req        ),
                .instr_mem_gnt          ( core_instr_mem_gnt        ),
                .instr_mem_valid        ( core_instr_mem_valid      ),
                .instr_mem_addr         ( core_instr_mem_addr       ),
                .instr_mem_be           ( core_instr_mem_be         ),
                .instr_mem_we           ( core_instr_mem_we         ),
                .instr_mem_wdata        ( core_instr_mem_wdata      ),
                .instr_mem_rdata        ( core_instr_mem_rdata      ),
                .instr_mem_error        ( core_instr_mem_error      ), // Although unused

                // Data memory interface
                .data_mem_req           ( core_data_mem_req         ),
                .data_mem_valid         ( core_data_mem_valid       ),
                .data_mem_gnt           ( core_data_mem_gnt         ),
                .data_mem_we            ( core_data_mem_we          ),
                .data_mem_be            ( core_data_mem_be          ),
                .data_mem_addr          ( core_data_mem_addr        ),
                .data_mem_wdata         ( core_data_mem_wdata       ),
                .data_mem_rdata         ( core_data_mem_rdata       ),
                .data_mem_error         ( core_data_mem_error       ), // Although unused

                .irq_software_i         ( irq_i[CORE_SW_INTERRUPT] ),
                .irq_timer_i            ( irq_i[CORE_TIM_INTERRUPT] ),
                .irq_external_i         ( irq_i[CORE_EXT_INTERRUPT] ),
                .irq_fast_i             ( '0 ),
                .irq_nm_i               ( '0 ),

                .debug_req_i            ( debug_req_core )

            );
        end
        else if (CORE_SELECTOR == CORE_MICROBLAZEV_RV32) begin : xlnx_microblazev_rv32

            // Tie-off unused signals
            assign core_instr_mem_wdata = '0;
            assign core_instr_mem_we    = '0;
            assign core_instr_mem_be    = '0;

            //////////////////////////
            //    MICROBLAZE RV32   //
            //////////////////////////

            // Debug interface connections definition
            logic       dbg_sys_rst;
            logic       Dbg_Clk;      // wire Dbg_Clk_0
            logic       Dbg_TDI;      // wire Dbg_TDI_0
            logic       Dbg_TDO;      // wire Dbg_TDO_0
            logic [0:7] Dbg_Reg_En;   // wire [0 : 7] Dbg_Reg_En_0
            logic       Dbg_Capture;  // wire Dbg_Capture_0
            logic       Dbg_Shift;    // wire Dbg_Shift_0
            logic       Dbg_Update;   // wire Dbg_Update_0
            logic       Dbg_Rst;      // wire Dbg_Rst_0
            logic       Dbg_Disable;  // wire Dbg_Disable_0


            // Declare AXI interfaces for instruction memory port and data memory port for MicroblazeV
            `DECLARE_AXI_BUS(microblaze_data, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH);
            `DECLARE_AXILITE_BUS(microblaze_instr, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH);

            // Declare AXI interface for Protocol Converter
            `DECLARE_AXI_BUS(converter_instr, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH);

            // MICROBLAZE-V RV32 instance
            xlnx_microblazev_rv32 microblazev_u (
                // Clock and reset
                .Clk                ( clk_i       ), // input wire Clk
                .Reset              ( dbg_sys_rst ), // input wire Reset

                // Interrupts
                // Ublaze can only take one external interrupt, which we tie to EXT interrupt (from the PLIC)
                .Interrupt          ( irq_i[CORE_EXT_INTERRUPT] ), // input wire Interrupt
                .Interrupt_Address  ('0                         ), // input wire [0 : 31] Interrupt_Address
                .Interrupt_Ack      (                           ), // output wire [0 : 1] Interrupt_Ack

                // Debug port to MDMV
                .Dbg_Clk            ( Dbg_Clk     ), // input wire Dbg_Clk
                .Dbg_TDI            ( Dbg_TDI     ), // input wire Dbg_TDI
                .Dbg_TDO            ( Dbg_TDO     ), // output wire Dbg_TDO
                .Dbg_Reg_En         ( Dbg_Reg_En  ), // input wire [0 : 7] Dbg_Reg_En
                .Dbg_Shift          ( Dbg_Shift   ), // input wire Dbg_Shift
                .Dbg_Capture        ( Dbg_Capture ), // input wire Dbg_Capture
                .Dbg_Update         ( Dbg_Update  ), // input wire Dbg_Update
                .Debug_Rst          ( Dbg_Rst     ), // input wire Debug_Rst
                .Dbg_Disable        ( Dbg_Disable ), // input wire Dbg_Disable

                // Data port (AXI)
                .M_AXI_DP_AWADDR    ( microblaze_data_axi_awaddr    ), // output wire [31 : 0] M_AXI_DP_AWADDR
                .M_AXI_DP_AWLEN     ( microblaze_data_axi_awlen     ), // output wire [7 : 0] M_AXI_DP_AWLEN
                .M_AXI_DP_AWSIZE    ( microblaze_data_axi_awsize    ), // output wire [2 : 0] M_AXI_DP_AWSIZE
                .M_AXI_DP_AWBURST   ( microblaze_data_axi_awburst   ), // output wire [1 : 0] M_AXI_DP_AWBURST
                .M_AXI_DP_AWLOCK    ( microblaze_data_axi_awlock    ), // output wire M_AXI_DP_AWLOCK
                .M_AXI_DP_AWCACHE   ( microblaze_data_axi_awcache   ), // output wire [3 : 0] M_AXI_DP_AWCACHE
                .M_AXI_DP_AWPROT    ( microblaze_data_axi_awprot    ), // output wire [2 : 0] M_AXI_DP_AWPROT
                .M_AXI_DP_AWQOS     ( microblaze_data_axi_awqos     ), // output wire [3 : 0] M_AXI_DP_AWQOS
                .M_AXI_DP_AWVALID   ( microblaze_data_axi_awvalid   ), // output wire M_AXI_DP_AWVALID
                .M_AXI_DP_AWREADY   ( microblaze_data_axi_awready   ), // input wire M_AXI_DP_AWREADY
                .M_AXI_DP_WDATA     ( microblaze_data_axi_wdata     ), // output wire [31 : 0] M_AXI_DP_WDATA
                .M_AXI_DP_WSTRB     ( microblaze_data_axi_wstrb     ), // output wire [3 : 0] M_AXI_DP_WSTRB
                .M_AXI_DP_WLAST     ( microblaze_data_axi_wlast     ), // output wire M_AXI_DP_WLAST
                .M_AXI_DP_WVALID    ( microblaze_data_axi_wvalid    ), // output wire M_AXI_DP_WVALID
                .M_AXI_DP_WREADY    ( microblaze_data_axi_wready    ), // input wire M_AXI_DP_WREADY
                .M_AXI_DP_BRESP     ( microblaze_data_axi_bresp     ), // input wire [1 : 0] M_AXI_DP_BRESP
                .M_AXI_DP_BVALID    ( microblaze_data_axi_bvalid    ), // input wire M_AXI_DP_BVALID
                .M_AXI_DP_BREADY    ( microblaze_data_axi_bready    ), // output wire M_AXI_DP_BREADY
                .M_AXI_DP_ARADDR    ( microblaze_data_axi_araddr    ), // output wire [31 : 0] M_AXI_DP_ARADDR
                .M_AXI_DP_ARLEN     ( microblaze_data_axi_arlen     ), // output wire [7 : 0] M_AXI_DP_ARLEN
                .M_AXI_DP_ARSIZE    ( microblaze_data_axi_arsize    ), // output wire [2 : 0] M_AXI_DP_ARSIZE
                .M_AXI_DP_ARBURST   ( microblaze_data_axi_arburst   ), // output wire [1 : 0] M_AXI_DP_ARBURST
                .M_AXI_DP_ARLOCK    ( microblaze_data_axi_arlock    ), // output wire M_AXI_DP_ARLOCK
                .M_AXI_DP_ARCACHE   ( microblaze_data_axi_arcache   ), // output wire [3 : 0] M_AXI_DP_ARCACHE
                .M_AXI_DP_ARPROT    ( microblaze_data_axi_arprot    ), // output wire [2 : 0] M_AXI_DP_ARPROT
                .M_AXI_DP_ARQOS     ( microblaze_data_axi_arqos     ), // output wire [3 : 0] M_AXI_DP_ARQOS
                .M_AXI_DP_ARVALID   ( microblaze_data_axi_arvalid   ), // output wire M_AXI_DP_ARVALID
                .M_AXI_DP_ARREADY   ( microblaze_data_axi_arready   ), // input wire M_AXI_DP_ARREADY
                .M_AXI_DP_RDATA     ( microblaze_data_axi_rdata     ), // input wire [31 : 0] M_AXI_DP_RDATA
                .M_AXI_DP_RRESP     ( microblaze_data_axi_rresp     ), // input wire [1 : 0] M_AXI_DP_RRESP
                .M_AXI_DP_RLAST     ( microblaze_data_axi_rlast     ), // input wire M_AXI_DP_RLAST
                .M_AXI_DP_RVALID    ( microblaze_data_axi_rvalid    ), // input wire M_AXI_DP_RVALID
                .M_AXI_DP_RREADY    ( microblaze_data_axi_rready    ), // output wire M_AXI_DP_RREADY

                // Instruction port (AXI-lite)
                .M_AXI_IP_AWADDR    ( microblaze_instr_axilite_awaddr   ), // output wire [31 : 0] M_AXI_IP_AWADDR
                .M_AXI_IP_AWPROT    ( microblaze_instr_axilite_awprot   ), // output wire [2 : 0] M_AXI_IP_AWPROT
                .M_AXI_IP_AWVALID   ( microblaze_instr_axilite_awvalid  ), // output wire M_AXI_IP_AWVALID
                .M_AXI_IP_AWREADY   ( microblaze_instr_axilite_awready  ), // input wire M_AXI_IP_AWREADY
                .M_AXI_IP_WDATA     ( microblaze_instr_axilite_wdata    ), // output wire [31 : 0] M_AXI_IP_WDATA
                .M_AXI_IP_WSTRB     ( microblaze_instr_axilite_wstrb    ), // output wire [3 : 0] M_AXI_IP_WSTRB
                .M_AXI_IP_WVALID    ( microblaze_instr_axilite_wvalid   ), // output wire M_AXI_IP_WVALID
                .M_AXI_IP_WREADY    ( microblaze_instr_axilite_wready   ), // input wire M_AXI_IP_WREADY
                .M_AXI_IP_BRESP     ( microblaze_instr_axilite_bresp    ), // input wire [1 : 0] M_AXI_IP_BRESP
                .M_AXI_IP_BVALID    ( microblaze_instr_axilite_bvalid   ), // input wire M_AXI_IP_BVALID
                .M_AXI_IP_BREADY    ( microblaze_instr_axilite_bready   ), // output wire M_AXI_IP_BREADY
                .M_AXI_IP_ARADDR    ( microblaze_instr_axilite_araddr   ), // output wire [31 : 0] M_AXI_IP_ARADDR
                .M_AXI_IP_ARPROT    ( microblaze_instr_axilite_arprot   ), // output wire [2 : 0] M_AXI_IP_ARPROT
                .M_AXI_IP_ARVALID   ( microblaze_instr_axilite_arvalid  ), // output wire M_AXI_IP_ARVALID
                .M_AXI_IP_ARREADY   ( microblaze_instr_axilite_arready  ), // input wire M_AXI_IP_ARREADY
                .M_AXI_IP_RDATA     ( microblaze_instr_axilite_rdata    ), // input wire [31 : 0] M_AXI_IP_RDATA
                .M_AXI_IP_RRESP     ( microblaze_instr_axilite_rresp    ), // input wire [1 : 0] M_AXI_IP_RRESP
                .M_AXI_IP_RVALID    ( microblaze_instr_axilite_rvalid   ), // input wire M_AXI_IP_RVALID
                .M_AXI_IP_RREADY    ( microblaze_instr_axilite_rready   )  // output wire M_AXI_IP_RREADY
            );

            // Microblaze Debug Module V
            xlnx_microblaze_debug_module_v mdmv_u (
                .Debug_SYS_Rst  ( dbg_sys_rst   ), // output wire Debug_SYS_Rst
                .Dbg_Clk_0      ( Dbg_Clk       ), // output wire Dbg_Clk_0
                .Dbg_TDI_0      ( Dbg_TDI       ), // output wire Dbg_TDI_0
                .Dbg_TDO_0      ( Dbg_TDO       ), // input wire Dbg_TDO_0
                .Dbg_Reg_En_0   ( Dbg_Reg_En    ), // output wire [0 : 7] Dbg_Reg_En_0
                .Dbg_Capture_0  ( Dbg_Capture   ), // output wire Dbg_Capture_0
                .Dbg_Shift_0    ( Dbg_Shift     ), // output wire Dbg_Shift_0
                .Dbg_Update_0   ( Dbg_Update    ), // output wire Dbg_Update_0
                .Dbg_Rst_0      ( Dbg_Rst       ), // output wire Dbg_Rst_0
                .Dbg_Disable_0  ( Dbg_Disable   )  // output wire Dbg_Disable_0
            );


            // Attach to socket
            `ASSIGN_AXI_BUS(rv_socket_data , microblaze_data);
            `ASSIGN_AXI_BUS(rv_socket_instr , converter_instr);

            // Tie-off undriven ID signals
            // ID's are set to zero since they are not present in microblaze, while the crossbar have ID's of size 2.
            // Instruction
            assign converter_instr_axi_awid = '0;
            assign converter_instr_axi_arid = '0;
            // Data
            assign microblaze_data_axi_awid = '0;
            assign microblaze_data_axi_arid = '0;

            // Regions are not present in microblaze data implementation so they are set to 0.
            assign microblaze_data_axi_awregion ='0;
            assign microblaze_data_axi_arregion ='0;

            // Convert from MICROBLAZE-V (AXI-lite) to socket (AXI)
            // Only instruction port (AXI-lite), data port is socket compliant (AXI)
            xlnx_axilite_to_axi4_d32_converter axilite_to_axi4_converter_u (
                .aclk           ( clk_i                             ), // input wire aclk
                .aresetn        ( rst_ni                            ), // input wire aresetn
                // From Microblaze (AXI-lite)
                .s_axi_awaddr   ( microblaze_instr_axilite_awaddr   ), // input wire [31 : 0] s_axi_awaddr
                .s_axi_awprot   ( microblaze_instr_axilite_awprot   ), // input wire [2 : 0] s_axi_awprot
                .s_axi_awvalid  ( microblaze_instr_axilite_awvalid  ), // input wire s_axi_awvalid
                .s_axi_awready  ( microblaze_instr_axilite_awready  ), // output wire s_axi_awready
                .s_axi_wdata    ( microblaze_instr_axilite_wdata    ), // input wire [31 : 0] s_axi_wdata
                .s_axi_wstrb    ( microblaze_instr_axilite_wstrb    ), // input wire [3 : 0] s_axi_wstrb
                .s_axi_wvalid   ( microblaze_instr_axilite_wvalid   ), // input wire s_axi_wvalid
                .s_axi_wready   ( microblaze_instr_axilite_wready   ), // output wire s_axi_wready
                .s_axi_bresp    ( microblaze_instr_axilite_bresp    ), // output wire [1 : 0] s_axi_bresp
                .s_axi_bvalid   ( microblaze_instr_axilite_bvalid   ), // output wire s_axi_bvalid
                .s_axi_bready   ( microblaze_instr_axilite_bready   ), // input wire s_axi_bready
                .s_axi_araddr   ( microblaze_instr_axilite_araddr   ), // input wire [31 : 0] s_axi_araddr
                .s_axi_arprot   ( microblaze_instr_axilite_arprot   ), // input wire [2 : 0] s_axi_arprot
                .s_axi_arvalid  ( microblaze_instr_axilite_arvalid  ), // input wire s_axi_arvalid
                .s_axi_arready  ( microblaze_instr_axilite_arready  ), // output wire s_axi_arready
                .s_axi_rdata    ( microblaze_instr_axilite_rdata    ), // output wire [31 : 0] s_axi_rdata
                .s_axi_rresp    ( microblaze_instr_axilite_rresp    ), // output wire [1 : 0] s_axi_rresp
                .s_axi_rvalid   ( microblaze_instr_axilite_rvalid   ), // output wire s_axi_rvalid
                .s_axi_rready   ( microblaze_instr_axilite_rready   ), // input wire s_axi_rready
                // To socket (AXI)
                .m_axi_awaddr   ( converter_instr_axi_awaddr        ), // output wire [31 : 0] m_axi_awaddr
                .m_axi_awlen    ( converter_instr_axi_awlen         ), // output wire [7 : 0] m_axi_awlen
                .m_axi_awsize   ( converter_instr_axi_awsize        ), // output wire [2 : 0] m_axi_awsize
                .m_axi_awburst  ( converter_instr_axi_awburst       ), // output wire [1 : 0] m_axi_awburst
                .m_axi_awlock   ( converter_instr_axi_awlock        ), // output wire [0 : 0] m_axi_awlock
                .m_axi_awcache  ( converter_instr_axi_awcache       ), // output wire [3 : 0] m_axi_awcache
                .m_axi_awprot   ( converter_instr_axi_awprot        ), // output wire [2 : 0] m_axi_awprot
                .m_axi_awregion ( converter_instr_axi_awregion      ), // output wire [3 : 0] m_axi_awregion
                .m_axi_awqos    ( converter_instr_axi_awqos         ), // output wire [3 : 0] m_axi_awqos
                .m_axi_awvalid  ( converter_instr_axi_awvalid       ), // output wire m_axi_awvalid
                .m_axi_awready  ( converter_instr_axi_awready       ), // input wire m_axi_awready
                .m_axi_wdata    ( converter_instr_axi_wdata         ), // output wire [31 : 0] m_axi_wdata
                .m_axi_wstrb    ( converter_instr_axi_wstrb         ), // output wire [3 : 0] m_axi_wstrb
                .m_axi_wlast    ( converter_instr_axi_wlast         ), // output wire m_axi_wlast
                .m_axi_wvalid   ( converter_instr_axi_wvalid        ), // output wire m_axi_wvalid
                .m_axi_wready   ( converter_instr_axi_wready        ), // input wire m_axi_wready
                .m_axi_bresp    ( converter_instr_axi_bresp         ), // input wire [1 : 0] m_axi_bresp
                .m_axi_bvalid   ( converter_instr_axi_bvalid        ), // input wire m_axi_bvalid
                .m_axi_bready   ( converter_instr_axi_bready        ), // output wire m_axi_bready
                .m_axi_araddr   ( converter_instr_axi_araddr        ), // output wire [31 : 0] m_axi_araddr
                .m_axi_arlen    ( converter_instr_axi_arlen         ), // output wire [7 : 0] m_axi_arlen
                .m_axi_arsize   ( converter_instr_axi_arsize        ), // output wire [2 : 0] m_axi_arsize
                .m_axi_arburst  ( converter_instr_axi_arburst       ), // output wire [1 : 0] m_axi_arburst
                .m_axi_arlock   ( converter_instr_axi_arlock        ), // output wire [0 : 0] m_axi_arlock
                .m_axi_arcache  ( converter_instr_axi_arcache       ), // output wire [3 : 0] m_axi_arcache
                .m_axi_arprot   ( converter_instr_axi_arprot        ), // output wire [2 : 0] m_axi_arprot
                .m_axi_arregion ( converter_instr_axi_arregion      ), // output wire [3 : 0] m_axi_arregion
                .m_axi_arqos    ( converter_instr_axi_arqos         ), // output wire [3 : 0] m_axi_arqos
                .m_axi_arvalid  ( converter_instr_axi_arvalid       ), // output wire m_axi_arvalid
                .m_axi_arready  ( converter_instr_axi_arready       ), // input wire m_axi_arready
                .m_axi_rdata    ( converter_instr_axi_rdata         ), // input wire [31 : 0] m_axi_rdata
                .m_axi_rresp    ( converter_instr_axi_rresp         ), // input wire [1 : 0] m_axi_rresp
                .m_axi_rlast    ( converter_instr_axi_rlast         ), // input wire m_axi_rlast
                .m_axi_rvalid   ( converter_instr_axi_rvalid        ), // input wire m_axi_rvalid
                .m_axi_rready   ( converter_instr_axi_rready        )  // output wire m_axi_rready
            );
        end : xlnx_microblazev_rv32

        else if (CORE_SELECTOR == CORE_MICROBLAZEV_RV64) begin : xlnx_microblazev_rv64

            // Tie-off unused signals
            assign core_instr_mem_wdata = '0;
            assign core_instr_mem_we    = '0;
            assign core_instr_mem_be    = '0;

            //////////////////////////
            //  MICROBLAZE-V RV64   //
            //////////////////////////

            // Debug interface connections definition
            logic       dbg_sys_rst;
            logic       Dbg_Clk;      // wire Dbg_Clk_0
            logic       Dbg_TDI;      // wire Dbg_TDI_0
            logic       Dbg_TDO;      // wire Dbg_TDO_0
            logic [0:7] Dbg_Reg_En;   // wire [0 : 7] Dbg_Reg_En_0
            logic       Dbg_Capture;  // wire Dbg_Capture_0
            logic       Dbg_Shift;    // wire Dbg_Shift_0
            logic       Dbg_Update;   // wire Dbg_Update_0
            logic       Dbg_Rst;      // wire Dbg_Rst_0
            logic       Dbg_Disable;  // wire Dbg_Disable_0


            // Declare AXI interfaces for instruction memory port and data memory port for MicroblazeV
            `DECLARE_AXI_BUS(microblaze_data, 32, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH);
            `DECLARE_AXILITE_BUS(microblaze_instr, 32, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH);

            // Declare AXI dwith 32-64 adapters
            `DECLARE_AXI_BUS(dwidth_conv_to_d64_data, 64, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH);
            `DECLARE_AXI_BUS(dwidth_conv_from_d32_instr, 32, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH);
            `DECLARE_AXI_BUS(dwidth_conv_to_d64_instr, 64, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH);

            // Microblaze-V 64 instance
            xlnx_microblazev_rv64 microblazev_u (
                // Clock and reset
                .Clk                ( clk_i       ), // input wire Clk
                .Reset              ( dbg_sys_rst ), // input wire Reset

                // Interrupts
                // Ublaze can only take one external interrupt, which we tie to EXT interrupt (from the PLIC)
                .Interrupt          ( irq_i[CORE_EXT_INTERRUPT] ), // input wire Interrupt
                .Interrupt_Address  ('0                         ), // input wire [0 : 31] Interrupt_Address
                .Interrupt_Ack      (                           ), // output wire [0 : 1] Interrupt_Ack

                // Debug port to MDMV
                .Dbg_Clk            ( Dbg_Clk     ), // input wire Dbg_Clk
                .Dbg_TDI            ( Dbg_TDI     ), // input wire Dbg_TDI
                .Dbg_TDO            ( Dbg_TDO     ), // output wire Dbg_TDO
                .Dbg_Reg_En         ( Dbg_Reg_En  ), // input wire [0 : 7] Dbg_Reg_En
                .Dbg_Shift          ( Dbg_Shift   ), // input wire Dbg_Shift
                .Dbg_Capture        ( Dbg_Capture ), // input wire Dbg_Capture
                .Dbg_Update         ( Dbg_Update  ), // input wire Dbg_Update
                .Debug_Rst          ( Dbg_Rst     ), // input wire Debug_Rst
                .Dbg_Disable        ( Dbg_Disable ), // input wire Dbg_Disable

                // Data port (AXI)
                .M_AXI_DP_AWADDR    ( microblaze_data_axi_awaddr    ), // output wire [31 : 0] M_AXI_DP_AWADDR
                .M_AXI_DP_AWLEN     ( microblaze_data_axi_awlen     ), // output wire [7 : 0] M_AXI_DP_AWLEN
                .M_AXI_DP_AWSIZE    ( microblaze_data_axi_awsize    ), // output wire [2 : 0] M_AXI_DP_AWSIZE
                .M_AXI_DP_AWBURST   ( microblaze_data_axi_awburst   ), // output wire [1 : 0] M_AXI_DP_AWBURST
                .M_AXI_DP_AWLOCK    ( microblaze_data_axi_awlock    ), // output wire M_AXI_DP_AWLOCK
                .M_AXI_DP_AWCACHE   ( microblaze_data_axi_awcache   ), // output wire [3 : 0] M_AXI_DP_AWCACHE
                .M_AXI_DP_AWPROT    ( microblaze_data_axi_awprot    ), // output wire [2 : 0] M_AXI_DP_AWPROT
                .M_AXI_DP_AWQOS     ( microblaze_data_axi_awqos     ), // output wire [3 : 0] M_AXI_DP_AWQOS
                .M_AXI_DP_AWVALID   ( microblaze_data_axi_awvalid   ), // output wire M_AXI_DP_AWVALID
                .M_AXI_DP_AWREADY   ( microblaze_data_axi_awready   ), // input wire M_AXI_DP_AWREADY
                .M_AXI_DP_WDATA     ( microblaze_data_axi_wdata     ), // output wire [31 : 0] M_AXI_DP_WDATA
                .M_AXI_DP_WSTRB     ( microblaze_data_axi_wstrb     ), // output wire [3 : 0] M_AXI_DP_WSTRB
                .M_AXI_DP_WLAST     ( microblaze_data_axi_wlast     ), // output wire M_AXI_DP_WLAST
                .M_AXI_DP_WVALID    ( microblaze_data_axi_wvalid    ), // output wire M_AXI_DP_WVALID
                .M_AXI_DP_WREADY    ( microblaze_data_axi_wready    ), // input wire M_AXI_DP_WREADY
                .M_AXI_DP_BRESP     ( microblaze_data_axi_bresp     ), // input wire [1 : 0] M_AXI_DP_BRESP
                .M_AXI_DP_BVALID    ( microblaze_data_axi_bvalid    ), // input wire M_AXI_DP_BVALID
                .M_AXI_DP_BREADY    ( microblaze_data_axi_bready    ), // output wire M_AXI_DP_BREADY
                .M_AXI_DP_ARADDR    ( microblaze_data_axi_araddr    ), // output wire [31 : 0] M_AXI_DP_ARADDR
                .M_AXI_DP_ARLEN     ( microblaze_data_axi_arlen     ), // output wire [7 : 0] M_AXI_DP_ARLEN
                .M_AXI_DP_ARSIZE    ( microblaze_data_axi_arsize    ), // output wire [2 : 0] M_AXI_DP_ARSIZE
                .M_AXI_DP_ARBURST   ( microblaze_data_axi_arburst   ), // output wire [1 : 0] M_AXI_DP_ARBURST
                .M_AXI_DP_ARLOCK    ( microblaze_data_axi_arlock    ), // output wire M_AXI_DP_ARLOCK
                .M_AXI_DP_ARCACHE   ( microblaze_data_axi_arcache   ), // output wire [3 : 0] M_AXI_DP_ARCACHE
                .M_AXI_DP_ARPROT    ( microblaze_data_axi_arprot    ), // output wire [2 : 0] M_AXI_DP_ARPROT
                .M_AXI_DP_ARQOS     ( microblaze_data_axi_arqos     ), // output wire [3 : 0] M_AXI_DP_ARQOS
                .M_AXI_DP_ARVALID   ( microblaze_data_axi_arvalid   ), // output wire M_AXI_DP_ARVALID
                .M_AXI_DP_ARREADY   ( microblaze_data_axi_arready   ), // input wire M_AXI_DP_ARREADY
                .M_AXI_DP_RDATA     ( microblaze_data_axi_rdata     ), // input wire [31 : 0] M_AXI_DP_RDATA
                .M_AXI_DP_RRESP     ( microblaze_data_axi_rresp     ), // input wire [1 : 0] M_AXI_DP_RRESP
                .M_AXI_DP_RLAST     ( microblaze_data_axi_rlast     ), // input wire M_AXI_DP_RLAST
                .M_AXI_DP_RVALID    ( microblaze_data_axi_rvalid    ), // input wire M_AXI_DP_RVALID
                .M_AXI_DP_RREADY    ( microblaze_data_axi_rready    ), // output wire M_AXI_DP_RREADY

                // Instruction port (AXI-lite)
                .M_AXI_IP_AWADDR    ( microblaze_instr_axilite_awaddr   ), // output wire [31 : 0] M_AXI_IP_AWADDR
                .M_AXI_IP_AWPROT    ( microblaze_instr_axilite_awprot   ), // output wire [2 : 0] M_AXI_IP_AWPROT
                .M_AXI_IP_AWVALID   ( microblaze_instr_axilite_awvalid  ), // output wire M_AXI_IP_AWVALID
                .M_AXI_IP_AWREADY   ( microblaze_instr_axilite_awready  ), // input wire M_AXI_IP_AWREADY
                .M_AXI_IP_WDATA     ( microblaze_instr_axilite_wdata    ), // output wire [31 : 0] M_AXI_IP_WDATA
                .M_AXI_IP_WSTRB     ( microblaze_instr_axilite_wstrb    ), // output wire [3 : 0] M_AXI_IP_WSTRB
                .M_AXI_IP_WVALID    ( microblaze_instr_axilite_wvalid   ), // output wire M_AXI_IP_WVALID
                .M_AXI_IP_WREADY    ( microblaze_instr_axilite_wready   ), // input wire M_AXI_IP_WREADY
                .M_AXI_IP_BRESP     ( microblaze_instr_axilite_bresp    ), // input wire [1 : 0] M_AXI_IP_BRESP
                .M_AXI_IP_BVALID    ( microblaze_instr_axilite_bvalid   ), // input wire M_AXI_IP_BVALID
                .M_AXI_IP_BREADY    ( microblaze_instr_axilite_bready   ), // output wire M_AXI_IP_BREADY
                .M_AXI_IP_ARADDR    ( microblaze_instr_axilite_araddr   ), // output wire [31 : 0] M_AXI_IP_ARADDR
                .M_AXI_IP_ARPROT    ( microblaze_instr_axilite_arprot   ), // output wire [2 : 0] M_AXI_IP_ARPROT
                .M_AXI_IP_ARVALID   ( microblaze_instr_axilite_arvalid  ), // output wire M_AXI_IP_ARVALID
                .M_AXI_IP_ARREADY   ( microblaze_instr_axilite_arready  ), // input wire M_AXI_IP_ARREADY
                .M_AXI_IP_RDATA     ( microblaze_instr_axilite_rdata    ), // input wire [31 : 0] M_AXI_IP_RDATA
                .M_AXI_IP_RRESP     ( microblaze_instr_axilite_rresp    ), // input wire [1 : 0] M_AXI_IP_RRESP
                .M_AXI_IP_RVALID    ( microblaze_instr_axilite_rvalid   ), // input wire M_AXI_IP_RVALID
                .M_AXI_IP_RREADY    ( microblaze_instr_axilite_rready   )  // output wire M_AXI_IP_RREADY
            );

            xlnx_axi_dwidth_32_to_64_converter data_dwidth_conv_u (
                .s_axi_aclk     ( clk_i  ),
                .s_axi_aresetn  ( rst_ni ),

                // Slave
                .s_axi_awid     ( microblaze_data_axi_awid     ),
                .s_axi_awaddr   ( microblaze_data_axi_awaddr   ),
                .s_axi_awlen    ( microblaze_data_axi_awlen    ),
                .s_axi_awsize   ( microblaze_data_axi_awsize   ),
                .s_axi_awburst  ( microblaze_data_axi_awburst  ),
                .s_axi_awvalid  ( microblaze_data_axi_awvalid  ),
                .s_axi_awready  ( microblaze_data_axi_awready  ),
                .s_axi_wdata    ( microblaze_data_axi_wdata    ),
                .s_axi_wstrb    ( microblaze_data_axi_wstrb    ),
                .s_axi_wlast    ( microblaze_data_axi_wlast    ),
                .s_axi_wvalid   ( microblaze_data_axi_wvalid   ),
                .s_axi_wready   ( microblaze_data_axi_wready   ),
                .s_axi_bid      ( microblaze_data_axi_bid      ),
                .s_axi_bresp    ( microblaze_data_axi_bresp    ),
                .s_axi_bvalid   ( microblaze_data_axi_bvalid   ),
                .s_axi_bready   ( microblaze_data_axi_bready   ),
                .s_axi_arid     ( microblaze_data_axi_arid     ),
                .s_axi_araddr   ( microblaze_data_axi_araddr   ),
                .s_axi_arlen    ( microblaze_data_axi_arlen    ),
                .s_axi_arsize   ( microblaze_data_axi_arsize   ),
                .s_axi_arburst  ( microblaze_data_axi_arburst  ),
                .s_axi_arvalid  ( microblaze_data_axi_arvalid  ),
                .s_axi_arready  ( microblaze_data_axi_arready  ),
                .s_axi_rid      ( microblaze_data_axi_rid      ),
                .s_axi_rdata    ( microblaze_data_axi_rdata    ),
                .s_axi_rresp    ( microblaze_data_axi_rresp    ),
                .s_axi_rlast    ( microblaze_data_axi_rlast    ),
                .s_axi_rvalid   ( microblaze_data_axi_rvalid   ),
                .s_axi_rready   ( microblaze_data_axi_rready   ),
                .s_axi_awlock   ( microblaze_data_axi_awlock   ),
                .s_axi_awcache  ( microblaze_data_axi_awcache  ),
                .s_axi_awprot   ( microblaze_data_axi_awprot   ),
                .s_axi_awqos    ( microblaze_data_axi_awqos    ),
                .s_axi_awregion ( microblaze_data_axi_awregion ),
                .s_axi_arlock   ( microblaze_data_axi_arlock   ),
                .s_axi_arcache  ( microblaze_data_axi_arcache  ),
                .s_axi_arprot   ( microblaze_data_axi_arprot   ),
                .s_axi_arqos    ( microblaze_data_axi_arqos    ),
                .s_axi_arregion ( microblaze_data_axi_arregion ),

                // Master
                .m_axi_awaddr   ( dwidth_conv_to_d64_data_axi_awaddr   ),
                .m_axi_awlen    ( dwidth_conv_to_d64_data_axi_awlen    ),
                .m_axi_awsize   ( dwidth_conv_to_d64_data_axi_awsize   ),
                .m_axi_awburst  ( dwidth_conv_to_d64_data_axi_awburst  ),
                .m_axi_awlock   ( dwidth_conv_to_d64_data_axi_awlock   ),
                .m_axi_awcache  ( dwidth_conv_to_d64_data_axi_awcache  ),
                .m_axi_awprot   ( dwidth_conv_to_d64_data_axi_awprot   ),
                .m_axi_awqos    ( dwidth_conv_to_d64_data_axi_awqos    ),
                .m_axi_awvalid  ( dwidth_conv_to_d64_data_axi_awvalid  ),
                .m_axi_awready  ( dwidth_conv_to_d64_data_axi_awready  ),
                .m_axi_awregion ( dwidth_conv_to_d64_data_axi_awregion ),
                .m_axi_wdata    ( dwidth_conv_to_d64_data_axi_wdata    ),
                .m_axi_wstrb    ( dwidth_conv_to_d64_data_axi_wstrb    ),
                .m_axi_wlast    ( dwidth_conv_to_d64_data_axi_wlast    ),
                .m_axi_wvalid   ( dwidth_conv_to_d64_data_axi_wvalid   ),
                .m_axi_wready   ( dwidth_conv_to_d64_data_axi_wready   ),
                .m_axi_bresp    ( dwidth_conv_to_d64_data_axi_bresp    ),
                .m_axi_bvalid   ( dwidth_conv_to_d64_data_axi_bvalid   ),
                .m_axi_bready   ( dwidth_conv_to_d64_data_axi_bready   ),
                .m_axi_arregion ( dwidth_conv_to_d64_data_axi_arregion ),
                .m_axi_araddr   ( dwidth_conv_to_d64_data_axi_araddr   ),
                .m_axi_arlen    ( dwidth_conv_to_d64_data_axi_arlen    ),
                .m_axi_arsize   ( dwidth_conv_to_d64_data_axi_arsize   ),
                .m_axi_arburst  ( dwidth_conv_to_d64_data_axi_arburst  ),
                .m_axi_arlock   ( dwidth_conv_to_d64_data_axi_arlock   ),
                .m_axi_arcache  ( dwidth_conv_to_d64_data_axi_arcache  ),
                .m_axi_arprot   ( dwidth_conv_to_d64_data_axi_arprot   ),
                .m_axi_arqos    ( dwidth_conv_to_d64_data_axi_arqos    ),
                .m_axi_arvalid  ( dwidth_conv_to_d64_data_axi_arvalid  ),
                .m_axi_arready  ( dwidth_conv_to_d64_data_axi_arready  ),
                .m_axi_rdata    ( dwidth_conv_to_d64_data_axi_rdata    ),
                .m_axi_rresp    ( dwidth_conv_to_d64_data_axi_rresp    ),
                .m_axi_rlast    ( dwidth_conv_to_d64_data_axi_rlast    ),
                .m_axi_rvalid   ( dwidth_conv_to_d64_data_axi_rvalid   ),
                .m_axi_rready   ( dwidth_conv_to_d64_data_axi_rready   )
            );

            xlnx_axi_dwidth_32_to_64_converter instr_dwidth_conv_u (
                .s_axi_aclk     ( clk_i  ),
                .s_axi_aresetn  ( rst_ni ),

                // Slave
                .s_axi_awid     ( dwidth_conv_from_d32_instr_axi_awid     ),
                .s_axi_awaddr   ( dwidth_conv_from_d32_instr_axi_awaddr   ),
                .s_axi_awlen    ( dwidth_conv_from_d32_instr_axi_awlen    ),
                .s_axi_awsize   ( dwidth_conv_from_d32_instr_axi_awsize   ),
                .s_axi_awburst  ( dwidth_conv_from_d32_instr_axi_awburst  ),
                .s_axi_awvalid  ( dwidth_conv_from_d32_instr_axi_awvalid  ),
                .s_axi_awready  ( dwidth_conv_from_d32_instr_axi_awready  ),
                .s_axi_wdata    ( dwidth_conv_from_d32_instr_axi_wdata    ),
                .s_axi_wstrb    ( dwidth_conv_from_d32_instr_axi_wstrb    ),
                .s_axi_wlast    ( dwidth_conv_from_d32_instr_axi_wlast    ),
                .s_axi_wvalid   ( dwidth_conv_from_d32_instr_axi_wvalid   ),
                .s_axi_wready   ( dwidth_conv_from_d32_instr_axi_wready   ),
                .s_axi_bid      ( dwidth_conv_from_d32_instr_axi_bid      ),
                .s_axi_bresp    ( dwidth_conv_from_d32_instr_axi_bresp    ),
                .s_axi_bvalid   ( dwidth_conv_from_d32_instr_axi_bvalid   ),
                .s_axi_bready   ( dwidth_conv_from_d32_instr_axi_bready   ),
                .s_axi_arid     ( dwidth_conv_from_d32_instr_axi_arid     ),
                .s_axi_araddr   ( dwidth_conv_from_d32_instr_axi_araddr   ),
                .s_axi_arlen    ( dwidth_conv_from_d32_instr_axi_arlen    ),
                .s_axi_arsize   ( dwidth_conv_from_d32_instr_axi_arsize   ),
                .s_axi_arburst  ( dwidth_conv_from_d32_instr_axi_arburst  ),
                .s_axi_arvalid  ( dwidth_conv_from_d32_instr_axi_arvalid  ),
                .s_axi_arready  ( dwidth_conv_from_d32_instr_axi_arready  ),
                .s_axi_rid      ( dwidth_conv_from_d32_instr_axi_rid      ),
                .s_axi_rdata    ( dwidth_conv_from_d32_instr_axi_rdata    ),
                .s_axi_rresp    ( dwidth_conv_from_d32_instr_axi_rresp    ),
                .s_axi_rlast    ( dwidth_conv_from_d32_instr_axi_rlast    ),
                .s_axi_rvalid   ( dwidth_conv_from_d32_instr_axi_rvalid   ),
                .s_axi_rready   ( dwidth_conv_from_d32_instr_axi_rready   ),
                .s_axi_awlock   ( dwidth_conv_from_d32_instr_axi_awlock   ),
                .s_axi_awcache  ( dwidth_conv_from_d32_instr_axi_awcache  ),
                .s_axi_awprot   ( dwidth_conv_from_d32_instr_axi_awprot   ),
                .s_axi_awqos    ( dwidth_conv_from_d32_instr_axi_awqos    ),
                .s_axi_awregion ( dwidth_conv_from_d32_instr_axi_awregion ),
                .s_axi_arlock   ( dwidth_conv_from_d32_instr_axi_arlock   ),
                .s_axi_arcache  ( dwidth_conv_from_d32_instr_axi_arcache  ),
                .s_axi_arprot   ( dwidth_conv_from_d32_instr_axi_arprot   ),
                .s_axi_arqos    ( dwidth_conv_from_d32_instr_axi_arqos    ),
                .s_axi_arregion ( dwidth_conv_from_d32_instr_axi_arregion ),

                // Master
                .m_axi_awaddr   ( dwidth_conv_to_d64_instr_axi_awaddr   ),
                .m_axi_awlen    ( dwidth_conv_to_d64_instr_axi_awlen    ),
                .m_axi_awsize   ( dwidth_conv_to_d64_instr_axi_awsize   ),
                .m_axi_awburst  ( dwidth_conv_to_d64_instr_axi_awburst  ),
                .m_axi_awlock   ( dwidth_conv_to_d64_instr_axi_awlock   ),
                .m_axi_awcache  ( dwidth_conv_to_d64_instr_axi_awcache  ),
                .m_axi_awprot   ( dwidth_conv_to_d64_instr_axi_awprot   ),
                .m_axi_awqos    ( dwidth_conv_to_d64_instr_axi_awqos    ),
                .m_axi_awvalid  ( dwidth_conv_to_d64_instr_axi_awvalid  ),
                .m_axi_awready  ( dwidth_conv_to_d64_instr_axi_awready  ),
                .m_axi_awregion ( dwidth_conv_to_d64_instr_axi_awregion ),
                .m_axi_wdata    ( dwidth_conv_to_d64_instr_axi_wdata    ),
                .m_axi_wstrb    ( dwidth_conv_to_d64_instr_axi_wstrb    ),
                .m_axi_wlast    ( dwidth_conv_to_d64_instr_axi_wlast    ),
                .m_axi_wvalid   ( dwidth_conv_to_d64_instr_axi_wvalid   ),
                .m_axi_wready   ( dwidth_conv_to_d64_instr_axi_wready   ),
                .m_axi_bresp    ( dwidth_conv_to_d64_instr_axi_bresp    ),
                .m_axi_bvalid   ( dwidth_conv_to_d64_instr_axi_bvalid   ),
                .m_axi_bready   ( dwidth_conv_to_d64_instr_axi_bready   ),
                .m_axi_araddr   ( dwidth_conv_to_d64_instr_axi_araddr   ),
                .m_axi_arlen    ( dwidth_conv_to_d64_instr_axi_arlen    ),
                .m_axi_arsize   ( dwidth_conv_to_d64_instr_axi_arsize   ),
                .m_axi_arburst  ( dwidth_conv_to_d64_instr_axi_arburst  ),
                .m_axi_arlock   ( dwidth_conv_to_d64_instr_axi_arlock   ),
                .m_axi_arcache  ( dwidth_conv_to_d64_instr_axi_arcache  ),
                .m_axi_arprot   ( dwidth_conv_to_d64_instr_axi_arprot   ),
                .m_axi_arqos    ( dwidth_conv_to_d64_instr_axi_arqos    ),
                .m_axi_arvalid  ( dwidth_conv_to_d64_instr_axi_arvalid  ),
                .m_axi_arready  ( dwidth_conv_to_d64_instr_axi_arready  ),
                .m_axi_arregion ( dwidth_conv_to_d64_instr_axi_arregion ),
                .m_axi_rdata    ( dwidth_conv_to_d64_instr_axi_rdata    ),
                .m_axi_rresp    ( dwidth_conv_to_d64_instr_axi_rresp    ),
                .m_axi_rlast    ( dwidth_conv_to_d64_instr_axi_rlast    ),
                .m_axi_rvalid   ( dwidth_conv_to_d64_instr_axi_rvalid   ),
                .m_axi_rready   ( dwidth_conv_to_d64_instr_axi_rready   )
            );

            // Convert from MICROBLAZE-V (AXI-lite) to socket (AXI)
            // Only instruction port (AXI-lite), data port is socket compliant (AXI)
            xlnx_axilite_to_axi4_d32_converter axilite_to_axi4_converter_u (
                .aclk           ( clk_i                             ), // input wire aclk
                .aresetn        ( rst_ni                            ), // input wire aresetn
                // From Microblaze (AXI-lite)
                .s_axi_awaddr   ( microblaze_instr_axilite_awaddr   ), // input wire [31 : 0] s_axi_awaddr
                .s_axi_awprot   ( microblaze_instr_axilite_awprot   ), // input wire [2 : 0] s_axi_awprot
                .s_axi_awvalid  ( microblaze_instr_axilite_awvalid  ), // input wire s_axi_awvalid
                .s_axi_awready  ( microblaze_instr_axilite_awready  ), // output wire s_axi_awready
                .s_axi_wdata    ( microblaze_instr_axilite_wdata    ), // input wire [31 : 0] s_axi_wdata
                .s_axi_wstrb    ( microblaze_instr_axilite_wstrb    ), // input wire [3 : 0] s_axi_wstrb
                .s_axi_wvalid   ( microblaze_instr_axilite_wvalid   ), // input wire s_axi_wvalid
                .s_axi_wready   ( microblaze_instr_axilite_wready   ), // output wire s_axi_wready
                .s_axi_bresp    ( microblaze_instr_axilite_bresp    ), // output wire [1 : 0] s_axi_bresp
                .s_axi_bvalid   ( microblaze_instr_axilite_bvalid   ), // output wire s_axi_bvalid
                .s_axi_bready   ( microblaze_instr_axilite_bready   ), // input wire s_axi_bready
                .s_axi_araddr   ( microblaze_instr_axilite_araddr   ), // input wire [31 : 0] s_axi_araddr
                .s_axi_arprot   ( microblaze_instr_axilite_arprot   ), // input wire [2 : 0] s_axi_arprot
                .s_axi_arvalid  ( microblaze_instr_axilite_arvalid  ), // input wire s_axi_arvalid
                .s_axi_arready  ( microblaze_instr_axilite_arready  ), // output wire s_axi_arready
                .s_axi_rdata    ( microblaze_instr_axilite_rdata    ), // output wire [31 : 0] s_axi_rdata
                .s_axi_rresp    ( microblaze_instr_axilite_rresp    ), // output wire [1 : 0] s_axi_rresp
                .s_axi_rvalid   ( microblaze_instr_axilite_rvalid   ), // output wire s_axi_rvalid
                .s_axi_rready   ( microblaze_instr_axilite_rready   ), // input wire s_axi_rready
                // To socket (AXI)
                .m_axi_awaddr   ( dwidth_conv_from_d32_instr_axi_awaddr   ), // output wire [31 : 0] m_axi_awaddr
                .m_axi_awlen    ( dwidth_conv_from_d32_instr_axi_awlen    ), // output wire [7 : 0] m_axi_awlen
                .m_axi_awsize   ( dwidth_conv_from_d32_instr_axi_awsize   ), // output wire [2 : 0] m_axi_awsize
                .m_axi_awburst  ( dwidth_conv_from_d32_instr_axi_awburst  ), // output wire [1 : 0] m_axi_awburst
                .m_axi_awlock   ( dwidth_conv_from_d32_instr_axi_awlock   ), // output wire [0 : 0] m_axi_awlock
                .m_axi_awcache  ( dwidth_conv_from_d32_instr_axi_awcache  ), // output wire [3 : 0] m_axi_awcache
                .m_axi_awprot   ( dwidth_conv_from_d32_instr_axi_awprot   ), // output wire [2 : 0] m_axi_awprot
                .m_axi_awregion ( dwidth_conv_from_d32_instr_axi_awregion ), // output wire [3 : 0] m_axi_awregion
                .m_axi_awqos    ( dwidth_conv_from_d32_instr_axi_awqos    ), // output wire [3 : 0] m_axi_awqos
                .m_axi_awvalid  ( dwidth_conv_from_d32_instr_axi_awvalid  ), // output wire m_axi_awvalid
                .m_axi_awready  ( dwidth_conv_from_d32_instr_axi_awready  ), // input wire m_axi_awready
                .m_axi_wdata    ( dwidth_conv_from_d32_instr_axi_wdata    ), // output wire [31 : 0] m_axi_wdata
                .m_axi_wstrb    ( dwidth_conv_from_d32_instr_axi_wstrb    ), // output wire [3 : 0] m_axi_wstrb
                .m_axi_wlast    ( dwidth_conv_from_d32_instr_axi_wlast    ), // output wire m_axi_wlast
                .m_axi_wvalid   ( dwidth_conv_from_d32_instr_axi_wvalid   ), // output wire m_axi_wvalid
                .m_axi_wready   ( dwidth_conv_from_d32_instr_axi_wready   ), // input wire m_axi_wready
                .m_axi_bresp    ( dwidth_conv_from_d32_instr_axi_bresp    ), // input wire [1 : 0] m_axi_bresp
                .m_axi_bvalid   ( dwidth_conv_from_d32_instr_axi_bvalid   ), // input wire m_axi_bvalid
                .m_axi_bready   ( dwidth_conv_from_d32_instr_axi_bready   ), // output wire m_axi_bready
                .m_axi_araddr   ( dwidth_conv_from_d32_instr_axi_araddr   ), // output wire [31 : 0] m_axi_araddr
                .m_axi_arlen    ( dwidth_conv_from_d32_instr_axi_arlen    ), // output wire [7 : 0] m_axi_arlen
                .m_axi_arsize   ( dwidth_conv_from_d32_instr_axi_arsize   ), // output wire [2 : 0] m_axi_arsize
                .m_axi_arburst  ( dwidth_conv_from_d32_instr_axi_arburst  ), // output wire [1 : 0] m_axi_arburst
                .m_axi_arlock   ( dwidth_conv_from_d32_instr_axi_arlock   ), // output wire [0 : 0] m_axi_arlock
                .m_axi_arcache  ( dwidth_conv_from_d32_instr_axi_arcache  ), // output wire [3 : 0] m_axi_arcache
                .m_axi_arprot   ( dwidth_conv_from_d32_instr_axi_arprot   ), // output wire [2 : 0] m_axi_arprot
                .m_axi_arregion ( dwidth_conv_from_d32_instr_axi_arregion ), // output wire [3 : 0] m_axi_arregion
                .m_axi_arqos    ( dwidth_conv_from_d32_instr_axi_arqos    ), // output wire [3 : 0] m_axi_arqos
                .m_axi_arvalid  ( dwidth_conv_from_d32_instr_axi_arvalid  ), // output wire m_axi_arvalid
                .m_axi_arready  ( dwidth_conv_from_d32_instr_axi_arready  ), // input wire m_axi_arready
                .m_axi_rdata    ( dwidth_conv_from_d32_instr_axi_rdata    ), // input wire [31 : 0] m_axi_rdata
                .m_axi_rresp    ( dwidth_conv_from_d32_instr_axi_rresp    ), // input wire [1 : 0] m_axi_rresp
                .m_axi_rlast    ( dwidth_conv_from_d32_instr_axi_rlast    ), // input wire m_axi_rlast
                .m_axi_rvalid   ( dwidth_conv_from_d32_instr_axi_rvalid   ), // input wire m_axi_rvalid
                .m_axi_rready   ( dwidth_conv_from_d32_instr_axi_rready   )  // output wire m_axi_rready
            );


            // Microblaze Debug Module V
            xlnx_microblaze_debug_module_v mdmv_u (
                .Debug_SYS_Rst  ( dbg_sys_rst   ), // output wire Debug_SYS_Rst
                .Dbg_Clk_0      ( Dbg_Clk       ), // output wire Dbg_Clk_0
                .Dbg_TDI_0      ( Dbg_TDI       ), // output wire Dbg_TDI_0
                .Dbg_TDO_0      ( Dbg_TDO       ), // input wire Dbg_TDO_0
                .Dbg_Reg_En_0   ( Dbg_Reg_En    ), // output wire [0 : 7] Dbg_Reg_En_0
                .Dbg_Capture_0  ( Dbg_Capture   ), // output wire Dbg_Capture_0
                .Dbg_Shift_0    ( Dbg_Shift     ), // output wire Dbg_Shift_0
                .Dbg_Update_0   ( Dbg_Update    ), // output wire Dbg_Update_0
                .Dbg_Rst_0      ( Dbg_Rst       ), // output wire Dbg_Rst_0
                .Dbg_Disable_0  ( Dbg_Disable   )  // output wire Dbg_Disable_0
            );

            // Attach to socket
            `ASSIGN_AXI_BUS(rv_socket_data , dwidth_conv_to_d64_data);
            `ASSIGN_AXI_BUS(rv_socket_instr , dwidth_conv_to_d64_instr);

            // Tie-off undriven ID signals
            // ID's are set to zero since they are not present in microblaze, while the crossbar have ID's of size 2.
            // Instruction
            assign dwidth_conv_to_d64_instr_axi_awid = '0;
            assign dwidth_conv_to_d64_instr_axi_arid = '0;

            // Data
            assign dwidth_conv_to_d64_data_axi_awid = '0;
            assign dwidth_conv_to_d64_data_axi_arid = '0;
        end : xlnx_microblazev_rv64

        else if (CORE_SELECTOR == CORE_CV64A6) begin: core_cv64a6

            ////////////////////////
            //      CV32A6        //
            ////////////////////////

            // CVA6 only has one Master port (for both data and instruction)
            `DECLARE_AXI_BUS(cv64a6, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH);

            custom_cv64a6 cv64a6_core (

                .clk_i           ( clk_i                            ),
                .rst_ni          ( core_resetn_internal             ),
                .boot_addr_i     ( bootaddr_i                       ),
                .hart_id_i       ( hart_id                          ),
                .irq_i           ( {0,irq_i[CORE_EXT_INTERRUPT]}    ), // Should be EXT interrupt. Bit zero is for M-mode, bit one is for S-mode
                .ipi_i           ( irq_i[CORE_SW_INTERRUPT]         ), // Shoult be SW interrupt
                .time_irq_i      ( irq_i[CORE_TIM_INTERRUPT]        ), // Should be TIM interrupt
                .debug_req_i     ( debug_req_core                   ),

                .m_axi_awaddr   ( cv64a6_axi_awaddr                 ), // output wire [31 : 0] m_axi_awaddr
                .m_axi_awlen    ( cv64a6_axi_awlen                  ), // output wire [7 : 0] m_axi_awlen
                .m_axi_awsize   ( cv64a6_axi_awsize                 ), // output wire [2 : 0] m_axi_awsize
                .m_axi_awburst  ( cv64a6_axi_awburst                ), // output wire [1 : 0] m_axi_awburst
                .m_axi_awlock   ( cv64a6_axi_awlock                 ), // output wire [0 : 0] m_axi_awlock
                .m_axi_awcache  ( cv64a6_axi_awcache                ), // output wire [3 : 0] m_axi_awcache
                .m_axi_awprot   ( cv64a6_axi_awprot                 ), // output wire [2 : 0] m_axi_awprot
                .m_axi_awregion ( cv64a6_axi_awregion               ), // output wire [3 : 0] m_axi_awregion
                .m_axi_awqos    ( cv64a6_axi_awqos                  ), // output wire [3 : 0] m_axi_awqos
                .m_axi_awvalid  ( cv64a6_axi_awvalid                ), // output wire m_axi_awvalid
                .m_axi_awready  ( cv64a6_axi_awready                ), // input wire m_axi_awready
                .m_axi_awid     ( cv64a6_axi_awid                   ),
                .m_axi_wdata    ( cv64a6_axi_wdata                  ), // output wire [31 : 0] m_axi_wdata
                .m_axi_wstrb    ( cv64a6_axi_wstrb                  ), // output wire [3 : 0] m_axi_wstrb
                .m_axi_wlast    ( cv64a6_axi_wlast                  ), // output wire m_axi_wlast
                .m_axi_wvalid   ( cv64a6_axi_wvalid                 ), // output wire m_axi_wvalid
                .m_axi_wready   ( cv64a6_axi_wready                 ), // input wire m_axi_wready
                .m_axi_bresp    ( cv64a6_axi_bresp                  ), // input wire [1 : 0] m_axi_bresp
                .m_axi_bvalid   ( cv64a6_axi_bvalid                 ), // input wire m_axi_bvalid
                .m_axi_bready   ( cv64a6_axi_bready                 ), // output wire m_axi_bready
                .m_axi_bid      ( cv64a6_axi_bid                    ), // output wire m_axi_bready
                .m_axi_araddr   ( cv64a6_axi_araddr                 ), // output wire [31 : 0] m_axi_araddr
                .m_axi_arlen    ( cv64a6_axi_arlen                  ), // output wire [7 : 0] m_axi_arlen
                .m_axi_arsize   ( cv64a6_axi_arsize                 ), // output wire [2 : 0] m_axi_arsize
                .m_axi_arburst  ( cv64a6_axi_arburst                ), // output wire [1 : 0] m_axi_arburst
                .m_axi_arlock   ( cv64a6_axi_arlock                 ), // output wire [0 : 0] m_axi_arlock
                .m_axi_arcache  ( cv64a6_axi_arcache                ), // output wire [3 : 0] m_axi_arcache
                .m_axi_arprot   ( cv64a6_axi_arprot                 ), // output wire [2 : 0] m_axi_arprot
                .m_axi_arregion ( cv64a6_axi_arregion               ), // output wire [3 : 0] m_axi_arregion
                .m_axi_arqos    ( cv64a6_axi_arqos                  ), // output wire [3 : 0] m_axi_arqos
                .m_axi_arvalid  ( cv64a6_axi_arvalid                ), // output wire m_axi_arvalid
                .m_axi_arready  ( cv64a6_axi_arready                ), // input wire m_axi_arready
                .m_axi_arid     ( cv64a6_axi_arid                   ),
                .m_axi_rdata    ( cv64a6_axi_rdata                  ), // input wire [31 : 0] m_axi_rdata
                .m_axi_rresp    ( cv64a6_axi_rresp                  ), // input wire [1 : 0] m_axi_rresp
                .m_axi_rlast    ( cv64a6_axi_rlast                  ), // input wire m_axi_rlast
                .m_axi_rvalid   ( cv64a6_axi_rvalid                 ), // input wire m_axi_rvalid
                .m_axi_rready   ( cv64a6_axi_rready                 ), // output wire m_axi_rready
                .m_axi_rid      ( cv64a6_axi_rid                    )  // output wire m_axi_rready

            );

            // Attach to socket (we only use data port)
            `ASSIGN_AXI_BUS( rv_socket_data , cv64a6 );
            `SINK_AXI_MASTER_INTERFACE(rv_socket_instr);

        end


    endgenerate


    //////////////////////////////////////////
    //     ___                              //
    //    / __|___ _ __  _ __  ___ _ _      //
    //   | (__/ _ | '  \| '  \/ _ | ' \     //
    //    \___\___|_|_|_|_|_|_\___|_||_|    //
    //                                      //
    //////////////////////////////////////////

    //////////////////////////////////////////////////////////////////////////
    // Here we are allocating commong module and signals.                   //
    //////////////////////////////////////////////////////////////////////////

    ///////////////////////////////////////////////////////////////////////////
    //  Cores (mem) to socket (AXI-Full) converters (Instruction and Data)   //
    ///////////////////////////////////////////////////////////////////////////

    // Few exceptions:
    // - MICROBLAZE-V have their own interfaces and debug module
    // - CVA6 Already has an AXI interface
    // - TODO: Rocket
    if ( !( CORE_SELECTOR inside {CORE_MICROBLAZEV_RV32, CORE_MICROBLAZEV_RV64, CORE_CV64A6} ) ) begin : mem_convert

        // Connect memory interfaces to socket output memory ports
        `ASSIGN_AXI_BUS( rv_socket_instr, core_instr_to_socket_instr );
        `ASSIGN_AXI_BUS( rv_socket_data, core_data_to_socket_data );

        // Convert instructions socket (AXI) to core (MEM)
        custom_axi_from_mem axi_from_mem_instr_u (
            // AXI side
            .m_axi_awid     ( core_instr_to_socket_instr_axi_awid       ),
            .m_axi_awaddr   ( core_instr_to_socket_instr_axi_awaddr     ),
            .m_axi_awlen    ( core_instr_to_socket_instr_axi_awlen      ),
            .m_axi_awsize   ( core_instr_to_socket_instr_axi_awsize     ),
            .m_axi_awburst  ( core_instr_to_socket_instr_axi_awburst    ),
            .m_axi_awlock   ( core_instr_to_socket_instr_axi_awlock     ),
            .m_axi_awcache  ( core_instr_to_socket_instr_axi_awcache    ),
            .m_axi_awprot   ( core_instr_to_socket_instr_axi_awprot     ),
            .m_axi_awqos    ( core_instr_to_socket_instr_axi_awqos      ),
            .m_axi_awregion ( core_instr_to_socket_instr_axi_awregion   ),
            .m_axi_awvalid  ( core_instr_to_socket_instr_axi_awvalid    ),
            .m_axi_awready  ( core_instr_to_socket_instr_axi_awready    ),
            .m_axi_wdata    ( core_instr_to_socket_instr_axi_wdata      ),
            .m_axi_wstrb    ( core_instr_to_socket_instr_axi_wstrb      ),
            .m_axi_wlast    ( core_instr_to_socket_instr_axi_wlast      ),
            .m_axi_wvalid   ( core_instr_to_socket_instr_axi_wvalid     ),
            .m_axi_wready   ( core_instr_to_socket_instr_axi_wready     ),
            .m_axi_bid      ( core_instr_to_socket_instr_axi_bid        ),
            .m_axi_bresp    ( core_instr_to_socket_instr_axi_bresp      ),
            .m_axi_bvalid   ( core_instr_to_socket_instr_axi_bvalid     ),
            .m_axi_bready   ( core_instr_to_socket_instr_axi_bready     ),
            .m_axi_araddr   ( core_instr_to_socket_instr_axi_araddr     ),
            .m_axi_arlen    ( core_instr_to_socket_instr_axi_arlen      ),
            .m_axi_arsize   ( core_instr_to_socket_instr_axi_arsize     ),
            .m_axi_arburst  ( core_instr_to_socket_instr_axi_arburst    ),
            .m_axi_arlock   ( core_instr_to_socket_instr_axi_arlock     ),
            .m_axi_arcache  ( core_instr_to_socket_instr_axi_arcache    ),
            .m_axi_arprot   ( core_instr_to_socket_instr_axi_arprot     ),
            .m_axi_arqos    ( core_instr_to_socket_instr_axi_arqos      ),
            .m_axi_arregion ( core_instr_to_socket_instr_axi_arregion   ),
            .m_axi_arvalid  ( core_instr_to_socket_instr_axi_arvalid    ),
            .m_axi_arready  ( core_instr_to_socket_instr_axi_arready    ),
            .m_axi_arid     ( core_instr_to_socket_instr_axi_arid       ),
            .m_axi_rid      ( core_instr_to_socket_instr_axi_rid        ),
            .m_axi_rdata    ( core_instr_to_socket_instr_axi_rdata      ),
            .m_axi_rresp    ( core_instr_to_socket_instr_axi_rresp      ),
            .m_axi_rlast    ( core_instr_to_socket_instr_axi_rlast      ),
            .m_axi_rvalid   ( core_instr_to_socket_instr_axi_rvalid     ),
            .m_axi_rready   ( core_instr_to_socket_instr_axi_rready     ),

            // MEM side
            .clk_i              ( clk_i                 ),
            .rst_ni             ( rst_ni                ),
            .s_mem_req          ( core_instr_mem_req    ),
            .s_mem_addr         ( core_instr_mem_addr   ),
            .s_mem_we           ( core_instr_mem_we     ),  // RO Interface
            .s_mem_wdata        ( core_instr_mem_wdata  ),  // RO Interface
            .s_mem_be           ( core_instr_mem_be     ),  // RO Interface
            .s_mem_gnt          ( core_instr_mem_gnt    ),
            .s_mem_valid        ( core_instr_mem_valid  ),
            .s_mem_rdata        ( core_instr_mem_rdata  ),
            .s_mem_error        ( core_instr_mem_error  )
        );

        // Convert instructions socket (AXI) to core (MEM)
        custom_axi_from_mem axi_from_mem_data_u (
            // AXI side
            .m_axi_awid     ( core_data_to_socket_data_axi_awid       ),
            .m_axi_awaddr   ( core_data_to_socket_data_axi_awaddr     ),
            .m_axi_awlen    ( core_data_to_socket_data_axi_awlen      ),
            .m_axi_awsize   ( core_data_to_socket_data_axi_awsize     ),
            .m_axi_awburst  ( core_data_to_socket_data_axi_awburst    ),
            .m_axi_awlock   ( core_data_to_socket_data_axi_awlock     ),
            .m_axi_awcache  ( core_data_to_socket_data_axi_awcache    ),
            .m_axi_awprot   ( core_data_to_socket_data_axi_awprot     ),
            .m_axi_awqos    ( core_data_to_socket_data_axi_awqos      ),
            .m_axi_awregion ( core_data_to_socket_data_axi_awregion   ),
            .m_axi_awvalid  ( core_data_to_socket_data_axi_awvalid    ),
            .m_axi_awready  ( core_data_to_socket_data_axi_awready    ),
            .m_axi_wdata    ( core_data_to_socket_data_axi_wdata      ),
            .m_axi_wstrb    ( core_data_to_socket_data_axi_wstrb      ),
            .m_axi_wlast    ( core_data_to_socket_data_axi_wlast      ),
            .m_axi_wvalid   ( core_data_to_socket_data_axi_wvalid     ),
            .m_axi_wready   ( core_data_to_socket_data_axi_wready     ),
            .m_axi_bid      ( core_data_to_socket_data_axi_bid        ),
            .m_axi_bresp    ( core_data_to_socket_data_axi_bresp      ),
            .m_axi_bvalid   ( core_data_to_socket_data_axi_bvalid     ),
            .m_axi_bready   ( core_data_to_socket_data_axi_bready     ),
            .m_axi_araddr   ( core_data_to_socket_data_axi_araddr     ),
            .m_axi_arlen    ( core_data_to_socket_data_axi_arlen      ),
            .m_axi_arsize   ( core_data_to_socket_data_axi_arsize     ),
            .m_axi_arburst  ( core_data_to_socket_data_axi_arburst    ),
            .m_axi_arlock   ( core_data_to_socket_data_axi_arlock     ),
            .m_axi_arcache  ( core_data_to_socket_data_axi_arcache    ),
            .m_axi_arprot   ( core_data_to_socket_data_axi_arprot     ),
            .m_axi_arqos    ( core_data_to_socket_data_axi_arqos      ),
            .m_axi_arregion ( core_data_to_socket_data_axi_arregion   ),
            .m_axi_arvalid  ( core_data_to_socket_data_axi_arvalid    ),
            .m_axi_arready  ( core_data_to_socket_data_axi_arready    ),
            .m_axi_arid     ( core_data_to_socket_data_axi_arid       ),
            .m_axi_rid      ( core_data_to_socket_data_axi_rid        ),
            .m_axi_rdata    ( core_data_to_socket_data_axi_rdata      ),
            .m_axi_rresp    ( core_data_to_socket_data_axi_rresp      ),
            .m_axi_rlast    ( core_data_to_socket_data_axi_rlast      ),
            .m_axi_rvalid   ( core_data_to_socket_data_axi_rvalid     ),
            .m_axi_rready   ( core_data_to_socket_data_axi_rready     ),

            // MEM side
            .clk_i              ( clk_i                     ),
            .rst_ni             ( rst_ni                    ),
            .s_mem_req          ( core_data_mem_req         ),
            .s_mem_addr         ( core_data_mem_addr        ),
            .s_mem_we           ( core_data_mem_we          ),
            .s_mem_wdata        ( core_data_mem_wdata       ),
            .s_mem_be           ( core_data_mem_be          ),
            .s_mem_gnt          ( core_data_mem_gnt         ),
            .s_mem_valid        ( core_data_mem_valid       ),
            .s_mem_rdata        ( core_data_mem_rdata       ),
            .s_mem_error        ( core_data_mem_error       )
        );
    end

    ///////////////////////////////////
    //    ___  ___ ___ _   _  ___    //
    //   |   \| __| _ ) | | |/ __|   //
    //   | |) | _|| _ \ |_| | (_ |   //
    //   |___/|___|___/\___/ \___|   //
    //                               //
    ///////////////////////////////////

    // This is only for PULP cores, that share a common debug module
    // Other cores are required to instatiate their own DM
    if ( CORE_SELECTOR inside {CORE_CV32E40P, CORE_IBEX} ) begin : dm_rv32_gen

        ///////////////////////////
        // Debug Module Instance //
        ///////////////////////////

        //  BSCANE2 tap
        (* keep_hierarchy = "yes" *)  // DEBUG
        custom_rv32_dbg_bscane riscv_dbg_u (
            .clk_i                  ( clk_i                   ),
            .rst_ni                 ( rst_ni                  ),
            .unavailable_i          ( '0                      ),
            .ndmreset_o             ( ndmreset_o              ), // Open
            .dmactive_o             ( dmactive_o              ), // Open
            // AXI Slave
            .dbg_slave_axi_awid         ( rv_socket_dbg_slave_axi_awid      ),
            .dbg_slave_axi_awaddr       ( rv_socket_dbg_slave_axi_awaddr    ),
            .dbg_slave_axi_awlen        ( rv_socket_dbg_slave_axi_awlen     ),
            .dbg_slave_axi_awsize       ( rv_socket_dbg_slave_axi_awsize    ),
            .dbg_slave_axi_awburst      ( rv_socket_dbg_slave_axi_awburst   ),
            .dbg_slave_axi_awlock       ( rv_socket_dbg_slave_axi_awlock    ),
            .dbg_slave_axi_awcache      ( rv_socket_dbg_slave_axi_awcache   ),
            .dbg_slave_axi_awprot       ( rv_socket_dbg_slave_axi_awprot    ),
            .dbg_slave_axi_awqos        ( rv_socket_dbg_slave_axi_awqos     ),
            .dbg_slave_axi_awvalid      ( rv_socket_dbg_slave_axi_awvalid   ),
            .dbg_slave_axi_awready      ( rv_socket_dbg_slave_axi_awready   ),
            .dbg_slave_axi_wdata        ( rv_socket_dbg_slave_axi_wdata     ),
            .dbg_slave_axi_wstrb        ( rv_socket_dbg_slave_axi_wstrb     ),
            .dbg_slave_axi_wlast        ( rv_socket_dbg_slave_axi_wlast     ),
            .dbg_slave_axi_wvalid       ( rv_socket_dbg_slave_axi_wvalid    ),
            .dbg_slave_axi_wready       ( rv_socket_dbg_slave_axi_wready    ),
            .dbg_slave_axi_bid          ( rv_socket_dbg_slave_axi_bid       ),
            .dbg_slave_axi_bresp        ( rv_socket_dbg_slave_axi_bresp     ),
            .dbg_slave_axi_bvalid       ( rv_socket_dbg_slave_axi_bvalid    ),
            .dbg_slave_axi_bready       ( rv_socket_dbg_slave_axi_bready    ),
            .dbg_slave_axi_arid         ( rv_socket_dbg_slave_axi_arid      ),
            .dbg_slave_axi_araddr       ( rv_socket_dbg_slave_axi_araddr    ),
            .dbg_slave_axi_arlen        ( rv_socket_dbg_slave_axi_arlen     ),
            .dbg_slave_axi_arsize       ( rv_socket_dbg_slave_axi_arsize    ),
            .dbg_slave_axi_arburst      ( rv_socket_dbg_slave_axi_arburst   ),
            .dbg_slave_axi_arlock       ( rv_socket_dbg_slave_axi_arlock    ),
            .dbg_slave_axi_arcache      ( rv_socket_dbg_slave_axi_arcache   ),
            .dbg_slave_axi_arprot       ( rv_socket_dbg_slave_axi_arprot    ),
            .dbg_slave_axi_arqos        ( rv_socket_dbg_slave_axi_arqos     ),
            .dbg_slave_axi_arvalid      ( rv_socket_dbg_slave_axi_arvalid   ),
            .dbg_slave_axi_arready      ( rv_socket_dbg_slave_axi_arready   ),
            .dbg_slave_axi_rid          ( rv_socket_dbg_slave_axi_rid       ),
            .dbg_slave_axi_rdata        ( rv_socket_dbg_slave_axi_rdata     ),
            .dbg_slave_axi_rresp        ( rv_socket_dbg_slave_axi_rresp     ),
            .dbg_slave_axi_rlast        ( rv_socket_dbg_slave_axi_rlast     ),
            .dbg_slave_axi_rvalid       ( rv_socket_dbg_slave_axi_rvalid    ),
            .dbg_slave_axi_rready       ( rv_socket_dbg_slave_axi_rready    ),
            // AXI Master
            .dbg_master_axi_awid        ( rv_socket_dbg_master_axi_awid     ),
            .dbg_master_axi_awaddr      ( rv_socket_dbg_master_axi_awaddr   ),
            .dbg_master_axi_awlen       ( rv_socket_dbg_master_axi_awlen    ),
            .dbg_master_axi_awsize      ( rv_socket_dbg_master_axi_awsize   ),
            .dbg_master_axi_awburst     ( rv_socket_dbg_master_axi_awburst  ),
            .dbg_master_axi_awlock      ( rv_socket_dbg_master_axi_awlock   ),
            .dbg_master_axi_awcache     ( rv_socket_dbg_master_axi_awcache  ),
            .dbg_master_axi_awprot      ( rv_socket_dbg_master_axi_awprot   ),
            .dbg_master_axi_awregion    ( rv_socket_dbg_master_axi_awregion ),
            .dbg_master_axi_awqos       ( rv_socket_dbg_master_axi_awqos    ),
            .dbg_master_axi_awvalid     ( rv_socket_dbg_master_axi_awvalid  ),
            .dbg_master_axi_awready     ( rv_socket_dbg_master_axi_awready  ),
            .dbg_master_axi_wdata       ( rv_socket_dbg_master_axi_wdata    ),
            .dbg_master_axi_wstrb       ( rv_socket_dbg_master_axi_wstrb    ),
            .dbg_master_axi_wlast       ( rv_socket_dbg_master_axi_wlast    ),
            .dbg_master_axi_wvalid      ( rv_socket_dbg_master_axi_wvalid   ),
            .dbg_master_axi_wready      ( rv_socket_dbg_master_axi_wready   ),
            .dbg_master_axi_bid         ( rv_socket_dbg_master_axi_bid      ),
            .dbg_master_axi_bresp       ( rv_socket_dbg_master_axi_bresp    ),
            .dbg_master_axi_bvalid      ( rv_socket_dbg_master_axi_bvalid   ),
            .dbg_master_axi_bready      ( rv_socket_dbg_master_axi_bready   ),
            .dbg_master_axi_arid        ( rv_socket_dbg_master_axi_arid     ),
            .dbg_master_axi_araddr      ( rv_socket_dbg_master_axi_araddr   ),
            .dbg_master_axi_arlen       ( rv_socket_dbg_master_axi_arlen    ),
            .dbg_master_axi_arsize      ( rv_socket_dbg_master_axi_arsize   ),
            .dbg_master_axi_arburst     ( rv_socket_dbg_master_axi_arburst  ),
            .dbg_master_axi_arlock      ( rv_socket_dbg_master_axi_arlock   ),
            .dbg_master_axi_arcache     ( rv_socket_dbg_master_axi_arcache  ),
            .dbg_master_axi_arprot      ( rv_socket_dbg_master_axi_arprot   ),
            .dbg_master_axi_arregion    ( rv_socket_dbg_master_axi_arregion ),
            .dbg_master_axi_arqos       ( rv_socket_dbg_master_axi_arqos    ),
            .dbg_master_axi_arvalid     ( rv_socket_dbg_master_axi_arvalid  ),
            .dbg_master_axi_arready     ( rv_socket_dbg_master_axi_arready  ),
            .dbg_master_axi_rid         ( rv_socket_dbg_master_axi_rid      ),
            .dbg_master_axi_rdata       ( rv_socket_dbg_master_axi_rdata    ),
            .dbg_master_axi_rresp       ( rv_socket_dbg_master_axi_rresp    ),
            .dbg_master_axi_rlast       ( rv_socket_dbg_master_axi_rlast    ),
            .dbg_master_axi_rvalid      ( rv_socket_dbg_master_axi_rvalid   ),
            .dbg_master_axi_rready      ( rv_socket_dbg_master_axi_rready   ),
            // To PULP core
            .debug_req_o            ( debug_req_core           )
        );

    end : dm_rv32_gen
    else if ( CORE_SELECTOR inside {CORE_CV64A6} ) begin : dm_rv64_gen

        // Debug Core built to use 64-bits interface.
        // It is technically compatible with all execution-based debug-mode cores.
        // In practice, it has only been used with CVA6
        //  BSCANE2 tap
        (* keep_hierarchy = "yes" *)  // DEBUG
        custom_rv64_dbg_bscane riscv_dbg_u (
            .clk_i                  ( clk_i                   ),
            .rst_ni                 ( rst_ni                  ),
            .unavailable_i          ( '0                      ),
            .ndmreset_o             ( ndmreset_o              ), // Open
            .dmactive_o             ( dmactive_o              ), // Open
            // AXI Slave
            .dbg_slave_axi_awid         ( rv_socket_dbg_slave_axi_awid      ),
            .dbg_slave_axi_awaddr       ( rv_socket_dbg_slave_axi_awaddr    ),
            .dbg_slave_axi_awlen        ( rv_socket_dbg_slave_axi_awlen     ),
            .dbg_slave_axi_awsize       ( rv_socket_dbg_slave_axi_awsize    ),
            .dbg_slave_axi_awburst      ( rv_socket_dbg_slave_axi_awburst   ),
            .dbg_slave_axi_awlock       ( rv_socket_dbg_slave_axi_awlock    ),
            .dbg_slave_axi_awcache      ( rv_socket_dbg_slave_axi_awcache   ),
            .dbg_slave_axi_awprot       ( rv_socket_dbg_slave_axi_awprot    ),
            .dbg_slave_axi_awqos        ( rv_socket_dbg_slave_axi_awqos     ),
            .dbg_slave_axi_awvalid      ( rv_socket_dbg_slave_axi_awvalid   ),
            .dbg_slave_axi_awready      ( rv_socket_dbg_slave_axi_awready   ),
            .dbg_slave_axi_wdata        ( rv_socket_dbg_slave_axi_wdata     ),
            .dbg_slave_axi_wstrb        ( rv_socket_dbg_slave_axi_wstrb     ),
            .dbg_slave_axi_wlast        ( rv_socket_dbg_slave_axi_wlast     ),
            .dbg_slave_axi_wvalid       ( rv_socket_dbg_slave_axi_wvalid    ),
            .dbg_slave_axi_wready       ( rv_socket_dbg_slave_axi_wready    ),
            .dbg_slave_axi_bid          ( rv_socket_dbg_slave_axi_bid       ),
            .dbg_slave_axi_bresp        ( rv_socket_dbg_slave_axi_bresp     ),
            .dbg_slave_axi_bvalid       ( rv_socket_dbg_slave_axi_bvalid    ),
            .dbg_slave_axi_bready       ( rv_socket_dbg_slave_axi_bready    ),
            .dbg_slave_axi_arid         ( rv_socket_dbg_slave_axi_arid      ),
            .dbg_slave_axi_araddr       ( rv_socket_dbg_slave_axi_araddr    ),
            .dbg_slave_axi_arlen        ( rv_socket_dbg_slave_axi_arlen     ),
            .dbg_slave_axi_arsize       ( rv_socket_dbg_slave_axi_arsize    ),
            .dbg_slave_axi_arburst      ( rv_socket_dbg_slave_axi_arburst   ),
            .dbg_slave_axi_arlock       ( rv_socket_dbg_slave_axi_arlock    ),
            .dbg_slave_axi_arcache      ( rv_socket_dbg_slave_axi_arcache   ),
            .dbg_slave_axi_arprot       ( rv_socket_dbg_slave_axi_arprot    ),
            .dbg_slave_axi_arqos        ( rv_socket_dbg_slave_axi_arqos     ),
            .dbg_slave_axi_arvalid      ( rv_socket_dbg_slave_axi_arvalid   ),
            .dbg_slave_axi_arready      ( rv_socket_dbg_slave_axi_arready   ),
            .dbg_slave_axi_rid          ( rv_socket_dbg_slave_axi_rid       ),
            .dbg_slave_axi_rdata        ( rv_socket_dbg_slave_axi_rdata     ),
            .dbg_slave_axi_rresp        ( rv_socket_dbg_slave_axi_rresp     ),
            .dbg_slave_axi_rlast        ( rv_socket_dbg_slave_axi_rlast     ),
            .dbg_slave_axi_rvalid       ( rv_socket_dbg_slave_axi_rvalid    ),
            .dbg_slave_axi_rready       ( rv_socket_dbg_slave_axi_rready    ),
            // AXI Master
            .dbg_master_axi_awid        ( rv_socket_dbg_master_axi_awid     ),
            .dbg_master_axi_awaddr      ( rv_socket_dbg_master_axi_awaddr   ),
            .dbg_master_axi_awlen       ( rv_socket_dbg_master_axi_awlen    ),
            .dbg_master_axi_awsize      ( rv_socket_dbg_master_axi_awsize   ),
            .dbg_master_axi_awburst     ( rv_socket_dbg_master_axi_awburst  ),
            .dbg_master_axi_awlock      ( rv_socket_dbg_master_axi_awlock   ),
            .dbg_master_axi_awcache     ( rv_socket_dbg_master_axi_awcache  ),
            .dbg_master_axi_awprot      ( rv_socket_dbg_master_axi_awprot   ),
            .dbg_master_axi_awregion    ( rv_socket_dbg_master_axi_awregion ),
            .dbg_master_axi_awqos       ( rv_socket_dbg_master_axi_awqos    ),
            .dbg_master_axi_awvalid     ( rv_socket_dbg_master_axi_awvalid  ),
            .dbg_master_axi_awready     ( rv_socket_dbg_master_axi_awready  ),
            .dbg_master_axi_wdata       ( rv_socket_dbg_master_axi_wdata    ),
            .dbg_master_axi_wstrb       ( rv_socket_dbg_master_axi_wstrb    ),
            .dbg_master_axi_wlast       ( rv_socket_dbg_master_axi_wlast    ),
            .dbg_master_axi_wvalid      ( rv_socket_dbg_master_axi_wvalid   ),
            .dbg_master_axi_wready      ( rv_socket_dbg_master_axi_wready   ),
            .dbg_master_axi_bid         ( rv_socket_dbg_master_axi_bid      ),
            .dbg_master_axi_bresp       ( rv_socket_dbg_master_axi_bresp    ),
            .dbg_master_axi_bvalid      ( rv_socket_dbg_master_axi_bvalid   ),
            .dbg_master_axi_bready      ( rv_socket_dbg_master_axi_bready   ),
            .dbg_master_axi_arid        ( rv_socket_dbg_master_axi_arid     ),
            .dbg_master_axi_araddr      ( rv_socket_dbg_master_axi_araddr   ),
            .dbg_master_axi_arlen       ( rv_socket_dbg_master_axi_arlen    ),
            .dbg_master_axi_arsize      ( rv_socket_dbg_master_axi_arsize   ),
            .dbg_master_axi_arburst     ( rv_socket_dbg_master_axi_arburst  ),
            .dbg_master_axi_arlock      ( rv_socket_dbg_master_axi_arlock   ),
            .dbg_master_axi_arcache     ( rv_socket_dbg_master_axi_arcache  ),
            .dbg_master_axi_arprot      ( rv_socket_dbg_master_axi_arprot   ),
            .dbg_master_axi_arregion    ( rv_socket_dbg_master_axi_arregion ),
            .dbg_master_axi_arqos       ( rv_socket_dbg_master_axi_arqos    ),
            .dbg_master_axi_arvalid     ( rv_socket_dbg_master_axi_arvalid  ),
            .dbg_master_axi_arready     ( rv_socket_dbg_master_axi_arready  ),
            .dbg_master_axi_rid         ( rv_socket_dbg_master_axi_rid      ),
            .dbg_master_axi_rdata       ( rv_socket_dbg_master_axi_rdata    ),
            .dbg_master_axi_rresp       ( rv_socket_dbg_master_axi_rresp    ),
            .dbg_master_axi_rlast       ( rv_socket_dbg_master_axi_rlast    ),
            .dbg_master_axi_rvalid      ( rv_socket_dbg_master_axi_rvalid   ),
            .dbg_master_axi_rready      ( rv_socket_dbg_master_axi_rready   ),
            // To PULP core
            .debug_req_o            ( debug_req_core           )
        );

    end : dm_rv64_gen
    else begin : dm_not_gen

        // Tie-off debug request signal to cores
        assign debug_req_core = '0;

        // Sink unused interafces
        `SINK_AXI_MASTER_INTERFACE(rv_socket_dbg_master);
        `SINK_AXI_SLAVE_INTERFACE(rv_socket_dbg_slave);

    end : dm_not_gen

endmodule : rv_socket
