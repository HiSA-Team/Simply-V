// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Description:
// This module is intended as a top-level wrapper for the code in ./rtl
// IT might support either MEM protocol or AXI protocol, using the
// uninasoc_axi and uninasoc_mem svh files in hw/xilinx/rtl


// Import headers
`include "uninasoc_mem.svh"
`include "uninasoc_axi.svh"

module custom_top_wrapper # (

    //////////////////////////////////////
    //  Add here IP-related parameters  //
    //////////////////////////////////////

    // TODO121: Automatically align with config
    // AXI/MEM macros parameter
    parameter LOCAL_DATA_WIDTH  = 32,
    parameter LOCAL_ADDR_WIDTH  = 32,

	parameter [ 0:0] ENABLE_COUNTERS      = 1,
	parameter [ 0:0] ENABLE_COUNTERS64    = 1,
	parameter [ 0:0] ENABLE_REGS_16_31    = 1,
	parameter [ 0:0] ENABLE_REGS_DUALPORT = 1,
	parameter [ 0:0] LATCHED_MEM_RDATA    = 0,
	parameter [ 0:0] TWO_STAGE_SHIFT      = 1,
	parameter [ 0:0] BARREL_SHIFTER       = 0,
	parameter [ 0:0] TWO_CYCLE_COMPARE    = 0,
	parameter [ 0:0] TWO_CYCLE_ALU        = 0,
	parameter [ 0:0] COMPRESSED_ISA       = 0,
	parameter [ 0:0] CATCH_MISALIGN       = 1,
	parameter [ 0:0] CATCH_ILLINSN        = 1,
	parameter [ 0:0] ENABLE_PCPI          = 0,
	parameter [ 0:0] ENABLE_MUL           = 1,
	parameter [ 0:0] ENABLE_FAST_MUL      = 1,
	parameter [ 0:0] ENABLE_DIV           = 1,
	parameter [ 0:0] ENABLE_IRQ           = 0,
	parameter [ 0:0] ENABLE_IRQ_QREGS     = 1,
	parameter [ 0:0] ENABLE_IRQ_TIMER     = 1,
	parameter [ 0:0] ENABLE_TRACE         = 0,
	parameter [ 0:0] REGS_INIT_ZERO       = 0,
	parameter [31:0] MASKED_IRQ           = 32'h 0000_0000,
	parameter [31:0] LATCHED_IRQ          = 32'h ffff_ffff,
	parameter [31:0] PROGADDR_RESET       = 32'h 0000_0000,
	parameter [31:0] PROGADDR_IRQ         = 32'h 0000_0010,
	parameter [31:0] STACKADDR            = 32'h ffff_ffff

) (

    ///////////////////////////////////
    //  Add here IP-related signals  //
    ///////////////////////////////////

    input  logic        clk_i,
    input  logic        rst_ni,
	output logic        trap_o,

    // IRQ Interface
	input  logic [31:0] irq_i,

`ifdef RISCV_FORMAL
	output logic        rvfi_valid,
	output logic [63:0] rvfi_order,
	output logic [31:0] rvfi_insn,
	output logic        rvfi_trap,
	output logic        rvfi_halt,
	output logic        rvfi_intr,
	output logic [ 1:0] rvfi_mode,
	output logic [ 1:0] rvfi_ixl,
	output logic [ 4:0] rvfi_rs1_addr,
	output logic [ 4:0] rvfi_rs2_addr,
	output logic [31:0] rvfi_rs1_rdata,
	output logic [31:0] rvfi_rs2_rdata,
	output logic [ 4:0] rvfi_rd_addr,
	output logic [31:0] rvfi_rd_wdata,
	output logic [31:0] rvfi_pc_rdata,
	output logic [31:0] rvfi_pc_wdata,
	output logic [31:0] rvfi_mem_addr,
	output logic [ 3:0] rvfi_mem_rmask,
	output logic [ 3:0] rvfi_mem_wmask,
	output logic [31:0] rvfi_mem_rdata,
	output logic [31:0] rvfi_mem_wdata,

	output logic [63:0] rvfi_csr_mcycle_rmask,
	output logic [63:0] rvfi_csr_mcycle_wmask,
	output logic [63:0] rvfi_csr_mcycle_rdata,
	output logic [63:0] rvfi_csr_mcycle_wdata,

	output logic [63:0] rvfi_csr_minstret_rmask,
	output logic [63:0] rvfi_csr_minstret_wmask,
	output logic [63:0] rvfi_csr_minstret_rdata,
	output logic [63:0] rvfi_csr_minstret_wdata,
`endif

	// Trace Interface
	output logic        trace_valid_o,
	output logic [35:0] trace_data_o,

    ////////////////////////////
    //  Bus Array Interfaces  //
    ////////////////////////////

    // MEM Master Interface Array
    `DEFINE_MEM_MASTER_PORTS(instr, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH),
    // MEM Slave Interface Array
    `DEFINE_MEM_MASTER_PORTS(data, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH)
);

    //////////////////////////
    //      PicoRV32        //
    //////////////////////////

    picorv32 #(
        .ENABLE_COUNTERS        (ENABLE_COUNTERS),
        .ENABLE_COUNTERS64      (ENABLE_COUNTERS64),
        .ENABLE_REGS_16_31      (ENABLE_REGS_16_31),
        .ENABLE_REGS_DUALPORT   (ENABLE_REGS_DUALPORT),
        .LATCHED_MEM_RDATA      (LATCHED_MEM_RDATA),
        .TWO_STAGE_SHIFT        (TWO_STAGE_SHIFT),
        .BARREL_SHIFTER         (BARREL_SHIFTER),
        .TWO_CYCLE_COMPARE      (TWO_CYCLE_COMPARE),
        .TWO_CYCLE_ALU          (TWO_CYCLE_ALU),
        .COMPRESSED_ISA         (COMPRESSED_ISA),
        .CATCH_MISALIGN         (CATCH_MISALIGN),
        .CATCH_ILLINSN          (CATCH_ILLINSN),
        .ENABLE_PCPI            (ENABLE_PCPI),
        .ENABLE_MUL             (ENABLE_MUL),
        .ENABLE_FAST_MUL        (ENABLE_FAST_MUL),
        .ENABLE_DIV             (ENABLE_DIV),
        .ENABLE_IRQ             (ENABLE_IRQ),
        .ENABLE_IRQ_QREGS       (ENABLE_IRQ_QREGS),
        .ENABLE_IRQ_TIMER       (ENABLE_IRQ_TIMER),
        .ENABLE_TRACE           (ENABLE_TRACE),
        .REGS_INIT_ZERO         (REGS_INIT_ZERO),
        .MASKED_IRQ             (MASKED_IRQ),
        .LATCHED_IRQ            (LATCHED_IRQ),
        .PROGADDR_RESET         (PROGADDR_RESET),
        .PROGADDR_IRQ           (PROGADDR_IRQ),
        .STACKADDR              (STACKADDR)
    ) core (
        .clk      	  (clk_i ),
        .resetn   	  (rst_ni),
        .trap     	  (trap),

        .mem_valid	  (mem_valid),
        .mem_addr 	  (mem_addr ),
        .mem_wdata	  (mem_data_wdata),
        .mem_wstrb	  (mem_wstrb),
        .mem_instr	  (mem_instr),
        .mem_ready	  (mem_ready),
        .mem_rdata	  (mem_rdata),

        // Ignored
        .mem_la_read  (),
        .mem_la_write (),
        .mem_la_addr  (),
        .mem_la_wdata (),
        .mem_la_wstrb (),
        .pcpi_valid	  (),
        .pcpi_insn 	  (),
        .pcpi_rs1  	  (),
        .pcpi_rs2  	  (),
        .pcpi_wr   	  ('0),
        .pcpi_rd   	  ('0),
        .pcpi_wait 	  ('0),
        .pcpi_ready	  ('0),

        .irq		      (irq_i),
        .eoi		      (),

    `ifdef RISCV_FORMAL
        .rvfi_valid    (),
        .rvfi_order    (),
        .rvfi_insn     (),
        .rvfi_trap     (),
        .rvfi_halt     (),
        .rvfi_intr     (),
        .rvfi_rs1_addr (),
        .rvfi_rs2_addr (),
        .rvfi_rs1_rdata(),
        .rvfi_rs2_rdata(),
        .rvfi_rd_addr  (),
        .rvfi_rd_wdata (),
        .rvfi_pc_rdata (),
        .rvfi_pc_wdata (),
        .rvfi_mem_addr (),
        .rvfi_mem_rmask(),
        .rvfi_mem_wmask(),
        .rvfi_mem_rdata(),
        .rvfi_mem_wdata(),
    `endif

        .trace_valid  (trace_valid),
        .trace_data   (trace_data)
    );


    //////////////////////////////
    //    Signal Definitions    //
    //////////////////////////////

    //  Trap, interrupts and trace signals. They might
    //  not be used outside of Pico.
    logic           trap;
	logic [31:0]    irq;
	logic [31:0]    eoi;
    logic           trace_valid;
    logic [35:0]    trace_data;

    //  This signal is used to distinguish between
    //  instr and data transactions
	logic           mem_instr;

    //  Memory signals
    logic           mem_instr_req;
	logic           mem_instr_gnt;
    logic           mem_instr_valid;
    logic [31:0]    mem_instr_addr;
	logic [31:0]    mem_instr_rdata;
    logic           mem_instr_error;
	logic           mem_data_req;
	logic           mem_data_gnt;
    logic           mem_data_valid;
    logic [31:0]    mem_data_addr;
	logic [31:0]    mem_data_rdata;
	logic [31:0]    mem_data_wdata;
	logic [ 3:0]    mem_data_be;
    logic           mem_data_we;
    logic           mem_data_error;

    logic 		    mem_valid;
	logic           mem_ready;
    logic [31:0]    mem_addr;
	logic [31:0]    mem_rdata;
    logic [3:0]     mem_wstrb;

    //////////////////////////
    //    Demultiplexing    //
    //////////////////////////

	// Instruction Transaction
	assign mem_instr_req    = (mem_instr) ? mem_valid: '0;
	assign mem_instr_addr   = (mem_instr) ? mem_addr: '0;
	// Data Transaction
	assign mem_data_req     = (~mem_instr) ? mem_valid: '0;
	assign mem_data_addr    = (~mem_instr) ? mem_addr: '0;
	assign mem_data_we      = (~mem_instr & |mem_wstrb) ? 1'b1: 1'b0;
    assign mem_data_be      = mem_wstrb;

    ////////////////////////
    //    Multiplexing    //
    ////////////////////////

    assign mem_ready = (mem_instr) ? instr_mem_valid : data_mem_valid;
    assign mem_rdata = (mem_instr) ? instr_mem_rdata : data_mem_rdata;

    ////////////////////////////////////
    //    Mem "lite" to Mem "full"    //
    //////////////////////////////////////////////////////////////////////////////////
    // Pico mem protocol uses different names compared to the "full" Mem protocol.  //
    // This was adjusted in the Demultiplexing section. In addition, Pico ignores   //
    // the gnt_i signal, but only cares for the valid one. When valid is asserted,  //
    // data is instantly available for the processor to be read. Therefore, this    //
    // section is empty, because the conversion only consists in demultiplexing     //
    // and ignoring both grant and error signals.                                   //
    //////////////////////////////////////////////////////////////////////////////////

    assign mem_instr_gnt    = instr_mem_gnt;
    assign mem_data_gnt     = data_mem_gnt;

    //////////////////////////////
    //    Output Assignments    //
    //////////////////////////////

    assign trace_valid_o    = trace_valid;
    assign trace_data_o     = trace_data;
    assign trap_o           = trap;

    assign instr_mem_req    = mem_instr_req;
    assign instr_mem_addr   = mem_instr_addr;
	assign data_mem_req     = mem_data_req;
    assign data_mem_addr    = mem_data_addr;
	assign data_mem_be      = mem_data_be;
    assign data_mem_we      = mem_data_we;
    assign data_mem_wdata   = mem_data_wdata;



endmodule : custom_top_wrapper


