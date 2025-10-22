// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Author: Zaira Abdel Majid <z.abdelmajid@studenti.unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Description: FPGA-ready top-level soft-SoC module for both hpc and embedded profiles.

// System architecture:
//
//                                                     __________                     ________
//   ____________                                     |          |                   |        |
//  |            |                                    |          |------------------>|  BRAM  |
//  | sys_master |----------------------------------->|          |                   |________|
//  |____________|                                    |          |                    ___________
//   ______________                                   |          |                   |           |
//  |              |--------------------------------->|          |------------------>|  DDR4CH1  |
//  | Debug Module |                                  |   Main   |                   |___________|
//  |______________|<---------------------------------|   Bus    |                    __________________
//                                                    |  (MBUS)  |                   |                  |
//                                                    |          |------------------>| High-performance |
//                                                    |          |                   |       bus        |
//                                                    |          |<------------------|     (HBUS)       |
//                                                    |          |                   |__________________|
//                                                    |          |                    ________________
//                                                    |          |                   |                |
//                                                    |          |------------------>| Peripheral bus |---------\
//                                                    |          |                   |     (PBUS)     |         |
//                                                    |          |                   |________________|         | peripheral
//   _________              ____________              |          |                    ________________          | interrupts
//  |         |            |            |             |          |                   |                |         |
//  |   vio   |----------->| rv_socket  |------------>|          |------------------>|      PLIC      |<--------/
//  |_________|            |____________|             |          |                   |________________|
//                                ^                   |          |                            |
//                                |                   |__________|                            |
//                                |                                                           |
//                                \___________________________________________________________/
//                                                 platform interrupt

/////////////////////
// Import packages //
/////////////////////

import uninasoc_pkg::*;

////////////////////
// Import headers //
////////////////////

`include "uninasoc_axi.svh"

`ifdef HPC
    `include "uninasoc_pcie.svh"
    `include "uninasoc_ddr4.svh"
`endif

///////////////////////
// Module definition //
///////////////////////

module uninasoc (

    `ifdef EMBEDDED
        // Clock and reset
        input logic sys_clock_i,
        input logic sys_reset_i,

        // UART interface
        input  logic                        uart_rx_i,
        output logic                        uart_tx_o,

        // GPIOs
        input  logic [GPIO_IN_WIDTH  -1 : 0]  gpio_in_i,
        output logic [GPIO_OUT_WIDTH -1 : 0]  gpio_out_o
    `elsif HPC
        // DDR4 Channel 0 clock and reset
        input logic clk_300mhz_0_p_i,
        input logic clk_300mhz_0_n_i,

        // DDR4 Channel 0 interface
        `DEFINE_DDR4_PORTS(0),

        // PCIe clock and reset
        input logic pcie_refclk_p_i,
        input logic pcie_refclk_n_i,
        input logic pcie_resetn_i,

        // PCIe interface
        `DEFINE_PCIE_PORTS
    `endif

);

    /////////////////////
    // Local variables //
    /////////////////////

    localparam peripherals_interrupts_num = 4;

    ///////////////////
    // Local Signals //
    //////////////////

    // CLOCKS
    logic main_clk;
    logic clk_10MHz;
    logic clk_20MHz;
    logic clk_50MHz;
    logic clk_100MHz;
    logic clk_250MHz;      // HPC ONLY

    // RESETS
    logic main_rstn;
    logic rstn_10MHz;
    logic rstn_20MHz;
    logic rstn_50MHz;
    logic rstn_100MHz;
    logic rstn_250MHz;     // HPC ONLY

    // VIO Signals
    logic vio_resetn;

    // Socket interrupts
    logic [31:0] rv_socket_interrupt_line;

    // Peripheral bus interrupts
    logic [peripherals_interrupts_num-1:0] pbus_int_line;

    /////////////////////////////////////////
    // Buses declaration and concatenation //
    /////////////////////////////////////////
    `include "mbus_buses.svinc"

    ///////////////////////
    // Clock assignments //
    ///////////////////////
    `include "uninasoc_clk_assignments.svinc"

    ///////////////////////
    // Local assignments //
    ///////////////////////

    /////////////
    // Modules //
    /////////////

    // Virtual I/O

    xlnx_vio vio_inst (
      .clk        ( main_clk        ),
      .probe_out0 ( vio_resetn      ),
      .probe_out1 (                 ),
      .probe_in0  ( main_rstn       )
    );

    // Axi Crossbar
    xlnx_main_crossbar main_xbar_u (
        .aclk           ( main_clk                  ), // input
        .aresetn        ( main_rstn                 ), // input
        .s_axi_awid     ( MBUS_masters_axi_awid     ), // input
        .s_axi_awaddr   ( MBUS_masters_axi_awaddr   ), // input
        .s_axi_awlen    ( MBUS_masters_axi_awlen    ), // input
        .s_axi_awsize   ( MBUS_masters_axi_awsize   ), // input
        .s_axi_awburst  ( MBUS_masters_axi_awburst  ), // input
        .s_axi_awlock   ( MBUS_masters_axi_awlock   ), // input
        .s_axi_awcache  ( MBUS_masters_axi_awcache  ), // input
        .s_axi_awprot   ( MBUS_masters_axi_awprot   ), // input
        .s_axi_awqos    ( MBUS_masters_axi_awqos    ), // input
        .s_axi_awvalid  ( MBUS_masters_axi_awvalid  ), // input
        .s_axi_awready  ( MBUS_masters_axi_awready  ), // output
        .s_axi_wdata    ( MBUS_masters_axi_wdata    ), // input
        .s_axi_wstrb    ( MBUS_masters_axi_wstrb    ), // input
        .s_axi_wlast    ( MBUS_masters_axi_wlast    ), // input
        .s_axi_wvalid   ( MBUS_masters_axi_wvalid   ), // input
        .s_axi_wready   ( MBUS_masters_axi_wready   ), // output
        .s_axi_bid      ( MBUS_masters_axi_bid      ), // output
        .s_axi_bresp    ( MBUS_masters_axi_bresp    ), // output
        .s_axi_bvalid   ( MBUS_masters_axi_bvalid   ), // output
        .s_axi_bready   ( MBUS_masters_axi_bready   ), // input
        .s_axi_arid     ( MBUS_masters_axi_arid     ), // output
        .s_axi_araddr   ( MBUS_masters_axi_araddr   ), // input
        .s_axi_arlen    ( MBUS_masters_axi_arlen    ), // input
        .s_axi_arsize   ( MBUS_masters_axi_arsize   ), // input
        .s_axi_arburst  ( MBUS_masters_axi_arburst  ), // input
        .s_axi_arlock   ( MBUS_masters_axi_arlock   ), // input
        .s_axi_arcache  ( MBUS_masters_axi_arcache  ), // input
        .s_axi_arprot   ( MBUS_masters_axi_arprot   ), // input
        .s_axi_arqos    ( MBUS_masters_axi_arqos    ), // input
        .s_axi_arvalid  ( MBUS_masters_axi_arvalid  ), // input
        .s_axi_arready  ( MBUS_masters_axi_arready  ), // output
        .s_axi_rid      ( MBUS_masters_axi_rid      ), // output
        .s_axi_rdata    ( MBUS_masters_axi_rdata    ), // output
        .s_axi_rresp    ( MBUS_masters_axi_rresp    ), // output
        .s_axi_rlast    ( MBUS_masters_axi_rlast    ), // output
        .s_axi_rvalid   ( MBUS_masters_axi_rvalid   ), // output
        .s_axi_rready   ( MBUS_masters_axi_rready   ), // input
        .m_axi_awid     ( MBUS_slaves_axi_awid      ), // output
        .m_axi_awaddr   ( MBUS_slaves_axi_awaddr    ), // output
        .m_axi_awlen    ( MBUS_slaves_axi_awlen     ), // output
        .m_axi_awsize   ( MBUS_slaves_axi_awsize    ), // output
        .m_axi_awburst  ( MBUS_slaves_axi_awburst   ), // output
        .m_axi_awlock   ( MBUS_slaves_axi_awlock    ), // output
        .m_axi_awcache  ( MBUS_slaves_axi_awcache   ), // output
        .m_axi_awprot   ( MBUS_slaves_axi_awprot    ), // output
        .m_axi_awregion ( MBUS_slaves_axi_awregion  ), // output
        .m_axi_awqos    ( MBUS_slaves_axi_awqos     ), // output
        .m_axi_awvalid  ( MBUS_slaves_axi_awvalid   ), // output
        .m_axi_awready  ( MBUS_slaves_axi_awready   ), // input
        .m_axi_wdata    ( MBUS_slaves_axi_wdata     ), // output
        .m_axi_wstrb    ( MBUS_slaves_axi_wstrb     ), // output
        .m_axi_wlast    ( MBUS_slaves_axi_wlast     ), // output
        .m_axi_wvalid   ( MBUS_slaves_axi_wvalid    ), // output
        .m_axi_wready   ( MBUS_slaves_axi_wready    ), // input
        .m_axi_bid      ( MBUS_slaves_axi_bid       ), // input
        .m_axi_bresp    ( MBUS_slaves_axi_bresp     ), // input
        .m_axi_bvalid   ( MBUS_slaves_axi_bvalid    ), // input
        .m_axi_bready   ( MBUS_slaves_axi_bready    ), // output
        .m_axi_arid     ( MBUS_slaves_axi_arid      ), // output
        .m_axi_araddr   ( MBUS_slaves_axi_araddr    ), // output
        .m_axi_arlen    ( MBUS_slaves_axi_arlen     ), // output
        .m_axi_arsize   ( MBUS_slaves_axi_arsize    ), // output
        .m_axi_arburst  ( MBUS_slaves_axi_arburst   ), // output
        .m_axi_arlock   ( MBUS_slaves_axi_arlock    ), // output
        .m_axi_arcache  ( MBUS_slaves_axi_arcache   ), // output
        .m_axi_arprot   ( MBUS_slaves_axi_arprot    ), // output
        .m_axi_arregion ( MBUS_slaves_axi_arregion  ), // output
        .m_axi_arqos    ( MBUS_slaves_axi_arqos     ), // output
        .m_axi_arvalid  ( MBUS_slaves_axi_arvalid   ), // output
        .m_axi_arready  ( MBUS_slaves_axi_arready   ), // input
        .m_axi_rid      ( MBUS_slaves_axi_rid       ), // input
        .m_axi_rdata    ( MBUS_slaves_axi_rdata     ), // input
        .m_axi_rresp    ( MBUS_slaves_axi_rresp     ), // input
        .m_axi_rlast    ( MBUS_slaves_axi_rlast     ), // input
        .m_axi_rvalid   ( MBUS_slaves_axi_rvalid    ), // input
        .m_axi_rready   ( MBUS_slaves_axi_rready    )  // output
    );

    /////////////////
    // AXI masters //
    /////////////////

    sys_master # (
        .LOCAL_DATA_WIDTH   ( MBUS_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH   ( MBUS_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH     ( MBUS_ID_WIDTH   )
    ) sys_master_u (

        // EMBEDDED ONLY
        .sys_clock_i(sys_clock_i),
        .sys_reset_i(sys_reset_i),

        // HPC ONLY
        .pcie_refclk_p_i(pcie_refclk_p_i),
        .pcie_refclk_n_i(pcie_refclk_n_i),
        .pcie_resetn_i(pcie_resetn_i),
        // PCI interface
        .pci_exp_rxn_i(pci_exp_rxn_i),
        .pci_exp_rxp_i(pci_exp_rxp_i),
        .pci_exp_txn_o(pci_exp_txn_o),
        .pci_exp_txp_o(pci_exp_txp_o),

        // Output clocks
        .clk_10MHz_o(clk_10MHz),
        .clk_20MHz_o(clk_20MHz),
        .clk_50MHz_o(clk_50MHz),
        .clk_100MHz_o(clk_100MHz),
        .clk_250MHz_o(clk_250MHz),      // HPC ONLY

        // Output resets
        .rstn_10MHz_o(rstn_10MHz),
        .rstn_20MHz_o(rstn_20MHz),
        .rstn_50MHz_o(rstn_50MHz),
        .rstn_100MHz_o(rstn_100MHz),
        .rstn_250MHz_o(rstn_250MHz),      // HPC ONLY

        // AXI Master
        .m_axi_awid     ( SYS_MASTER_to_MBUS_axi_awid     ),
        .m_axi_awaddr   ( SYS_MASTER_to_MBUS_axi_awaddr   ),
        .m_axi_awlen    ( SYS_MASTER_to_MBUS_axi_awlen    ),
        .m_axi_awsize   ( SYS_MASTER_to_MBUS_axi_awsize   ),
        .m_axi_awburst  ( SYS_MASTER_to_MBUS_axi_awburst  ),
        .m_axi_awlock   ( SYS_MASTER_to_MBUS_axi_awlock   ),
        .m_axi_awcache  ( SYS_MASTER_to_MBUS_axi_awcache  ),
        .m_axi_awprot   ( SYS_MASTER_to_MBUS_axi_awprot   ),
        .m_axi_awqos    ( SYS_MASTER_to_MBUS_axi_awqos    ),
        .m_axi_awvalid  ( SYS_MASTER_to_MBUS_axi_awvalid  ),
        .m_axi_awready  ( SYS_MASTER_to_MBUS_axi_awready  ),
        .m_axi_awregion ( SYS_MASTER_to_MBUS_axi_awregion ),
        .m_axi_wdata    ( SYS_MASTER_to_MBUS_axi_wdata    ),
        .m_axi_wstrb    ( SYS_MASTER_to_MBUS_axi_wstrb    ),
        .m_axi_wlast    ( SYS_MASTER_to_MBUS_axi_wlast    ),
        .m_axi_wvalid   ( SYS_MASTER_to_MBUS_axi_wvalid   ),
        .m_axi_wready   ( SYS_MASTER_to_MBUS_axi_wready   ),
        .m_axi_bid      ( SYS_MASTER_to_MBUS_axi_bid      ),
        .m_axi_bresp    ( SYS_MASTER_to_MBUS_axi_bresp    ),
        .m_axi_bvalid   ( SYS_MASTER_to_MBUS_axi_bvalid   ),
        .m_axi_bready   ( SYS_MASTER_to_MBUS_axi_bready   ),
        .m_axi_arid     ( SYS_MASTER_to_MBUS_axi_arid     ),
        .m_axi_araddr   ( SYS_MASTER_to_MBUS_axi_araddr   ),
        .m_axi_arlen    ( SYS_MASTER_to_MBUS_axi_arlen    ),
        .m_axi_arsize   ( SYS_MASTER_to_MBUS_axi_arsize   ),
        .m_axi_arburst  ( SYS_MASTER_to_MBUS_axi_arburst  ),
        .m_axi_arlock   ( SYS_MASTER_to_MBUS_axi_arlock   ),
        .m_axi_arcache  ( SYS_MASTER_to_MBUS_axi_arcache  ),
        .m_axi_arprot   ( SYS_MASTER_to_MBUS_axi_arprot   ),
        .m_axi_arqos    ( SYS_MASTER_to_MBUS_axi_arqos    ),
        .m_axi_arvalid  ( SYS_MASTER_to_MBUS_axi_arvalid  ),
        .m_axi_arready  ( SYS_MASTER_to_MBUS_axi_arready  ),
        .m_axi_arregion ( SYS_MASTER_to_MBUS_axi_arregion ),
        .m_axi_rid      ( SYS_MASTER_to_MBUS_axi_rid      ),
        .m_axi_rdata    ( SYS_MASTER_to_MBUS_axi_rdata    ),
        .m_axi_rresp    ( SYS_MASTER_to_MBUS_axi_rresp    ),
        .m_axi_rlast    ( SYS_MASTER_to_MBUS_axi_rlast    ),
        .m_axi_rvalid   ( SYS_MASTER_to_MBUS_axi_rvalid   ),
        .m_axi_rready   ( SYS_MASTER_to_MBUS_axi_rready   )
    );

    // RV Socket
    rv_socket # (

        .LOCAL_DATA_WIDTH   ( MBUS_DATA_WIDTH    ),
        .LOCAL_ADDR_WIDTH   ( MBUS_ADDR_WIDTH    ),
        .LOCAL_ID_WIDTH     ( MBUS_ID_WIDTH      ),
        .CORE_SELECTOR      ( CORE_SELECTOR      )

    ) rv_socket_u (
        .clk_i          ( main_clk   ),
        .rst_ni         ( main_rstn  ),
        .core_resetn_i  ( vio_resetn ),
        .bootaddr_i     ( '0         ),
        .irq_i          ( rv_socket_interrupt_line ),

        // Instruction AXI Port
        .rv_socket_instr_axi_awid      ( RV_SOCKET_INSTR_to_MBUS_axi_awid     ),
        .rv_socket_instr_axi_awaddr    ( RV_SOCKET_INSTR_to_MBUS_axi_awaddr   ),
        .rv_socket_instr_axi_awlen     ( RV_SOCKET_INSTR_to_MBUS_axi_awlen    ),
        .rv_socket_instr_axi_awsize    ( RV_SOCKET_INSTR_to_MBUS_axi_awsize   ),
        .rv_socket_instr_axi_awburst   ( RV_SOCKET_INSTR_to_MBUS_axi_awburst  ),
        .rv_socket_instr_axi_awlock    ( RV_SOCKET_INSTR_to_MBUS_axi_awlock   ),
        .rv_socket_instr_axi_awcache   ( RV_SOCKET_INSTR_to_MBUS_axi_awcache  ),
        .rv_socket_instr_axi_awprot    ( RV_SOCKET_INSTR_to_MBUS_axi_awprot   ),
        .rv_socket_instr_axi_awqos     ( RV_SOCKET_INSTR_to_MBUS_axi_awqos    ),
        .rv_socket_instr_axi_awvalid   ( RV_SOCKET_INSTR_to_MBUS_axi_awvalid  ),
        .rv_socket_instr_axi_awready   ( RV_SOCKET_INSTR_to_MBUS_axi_awready  ),
        .rv_socket_instr_axi_awregion  ( RV_SOCKET_INSTR_to_MBUS_axi_awregion ),
        .rv_socket_instr_axi_wdata     ( RV_SOCKET_INSTR_to_MBUS_axi_wdata    ),
        .rv_socket_instr_axi_wstrb     ( RV_SOCKET_INSTR_to_MBUS_axi_wstrb    ),
        .rv_socket_instr_axi_wlast     ( RV_SOCKET_INSTR_to_MBUS_axi_wlast    ),
        .rv_socket_instr_axi_wvalid    ( RV_SOCKET_INSTR_to_MBUS_axi_wvalid   ),
        .rv_socket_instr_axi_wready    ( RV_SOCKET_INSTR_to_MBUS_axi_wready   ),
        .rv_socket_instr_axi_bid       ( RV_SOCKET_INSTR_to_MBUS_axi_bid      ),
        .rv_socket_instr_axi_bresp     ( RV_SOCKET_INSTR_to_MBUS_axi_bresp    ),
        .rv_socket_instr_axi_bvalid    ( RV_SOCKET_INSTR_to_MBUS_axi_bvalid   ),
        .rv_socket_instr_axi_bready    ( RV_SOCKET_INSTR_to_MBUS_axi_bready   ),
        .rv_socket_instr_axi_arid      ( RV_SOCKET_INSTR_to_MBUS_axi_arid     ),
        .rv_socket_instr_axi_araddr    ( RV_SOCKET_INSTR_to_MBUS_axi_araddr   ),
        .rv_socket_instr_axi_arlen     ( RV_SOCKET_INSTR_to_MBUS_axi_arlen    ),
        .rv_socket_instr_axi_arsize    ( RV_SOCKET_INSTR_to_MBUS_axi_arsize   ),
        .rv_socket_instr_axi_arburst   ( RV_SOCKET_INSTR_to_MBUS_axi_arburst  ),
        .rv_socket_instr_axi_arlock    ( RV_SOCKET_INSTR_to_MBUS_axi_arlock   ),
        .rv_socket_instr_axi_arcache   ( RV_SOCKET_INSTR_to_MBUS_axi_arcache  ),
        .rv_socket_instr_axi_arprot    ( RV_SOCKET_INSTR_to_MBUS_axi_arprot   ),
        .rv_socket_instr_axi_arqos     ( RV_SOCKET_INSTR_to_MBUS_axi_arqos    ),
        .rv_socket_instr_axi_arvalid   ( RV_SOCKET_INSTR_to_MBUS_axi_arvalid  ),
        .rv_socket_instr_axi_arready   ( RV_SOCKET_INSTR_to_MBUS_axi_arready  ),
        .rv_socket_instr_axi_arregion  ( RV_SOCKET_INSTR_to_MBUS_axi_arregion ),
        .rv_socket_instr_axi_rid       ( RV_SOCKET_INSTR_to_MBUS_axi_rid      ),
        .rv_socket_instr_axi_rdata     ( RV_SOCKET_INSTR_to_MBUS_axi_rdata    ),
        .rv_socket_instr_axi_rresp     ( RV_SOCKET_INSTR_to_MBUS_axi_rresp    ),
        .rv_socket_instr_axi_rlast     ( RV_SOCKET_INSTR_to_MBUS_axi_rlast    ),
        .rv_socket_instr_axi_rvalid    ( RV_SOCKET_INSTR_to_MBUS_axi_rvalid   ),
        .rv_socket_instr_axi_rready    ( RV_SOCKET_INSTR_to_MBUS_axi_rready   ),

        // Data AXI Port
        .rv_socket_data_axi_awid      ( RV_SOCKET_DATA_to_MBUS_axi_awid     ),
        .rv_socket_data_axi_awaddr    ( RV_SOCKET_DATA_to_MBUS_axi_awaddr   ),
        .rv_socket_data_axi_awlen     ( RV_SOCKET_DATA_to_MBUS_axi_awlen    ),
        .rv_socket_data_axi_awsize    ( RV_SOCKET_DATA_to_MBUS_axi_awsize   ),
        .rv_socket_data_axi_awburst   ( RV_SOCKET_DATA_to_MBUS_axi_awburst  ),
        .rv_socket_data_axi_awlock    ( RV_SOCKET_DATA_to_MBUS_axi_awlock   ),
        .rv_socket_data_axi_awcache   ( RV_SOCKET_DATA_to_MBUS_axi_awcache  ),
        .rv_socket_data_axi_awprot    ( RV_SOCKET_DATA_to_MBUS_axi_awprot   ),
        .rv_socket_data_axi_awqos     ( RV_SOCKET_DATA_to_MBUS_axi_awqos    ),
        .rv_socket_data_axi_awvalid   ( RV_SOCKET_DATA_to_MBUS_axi_awvalid  ),
        .rv_socket_data_axi_awready   ( RV_SOCKET_DATA_to_MBUS_axi_awready  ),
        .rv_socket_data_axi_awregion  ( RV_SOCKET_DATA_to_MBUS_axi_awregion ),
        .rv_socket_data_axi_wdata     ( RV_SOCKET_DATA_to_MBUS_axi_wdata    ),
        .rv_socket_data_axi_wstrb     ( RV_SOCKET_DATA_to_MBUS_axi_wstrb    ),
        .rv_socket_data_axi_wlast     ( RV_SOCKET_DATA_to_MBUS_axi_wlast    ),
        .rv_socket_data_axi_wvalid    ( RV_SOCKET_DATA_to_MBUS_axi_wvalid   ),
        .rv_socket_data_axi_wready    ( RV_SOCKET_DATA_to_MBUS_axi_wready   ),
        .rv_socket_data_axi_bid       ( RV_SOCKET_DATA_to_MBUS_axi_bid      ),
        .rv_socket_data_axi_bresp     ( RV_SOCKET_DATA_to_MBUS_axi_bresp    ),
        .rv_socket_data_axi_bvalid    ( RV_SOCKET_DATA_to_MBUS_axi_bvalid   ),
        .rv_socket_data_axi_bready    ( RV_SOCKET_DATA_to_MBUS_axi_bready   ),
        .rv_socket_data_axi_arid      ( RV_SOCKET_DATA_to_MBUS_axi_arid     ),
        .rv_socket_data_axi_araddr    ( RV_SOCKET_DATA_to_MBUS_axi_araddr   ),
        .rv_socket_data_axi_arlen     ( RV_SOCKET_DATA_to_MBUS_axi_arlen    ),
        .rv_socket_data_axi_arsize    ( RV_SOCKET_DATA_to_MBUS_axi_arsize   ),
        .rv_socket_data_axi_arburst   ( RV_SOCKET_DATA_to_MBUS_axi_arburst  ),
        .rv_socket_data_axi_arlock    ( RV_SOCKET_DATA_to_MBUS_axi_arlock   ),
        .rv_socket_data_axi_arcache   ( RV_SOCKET_DATA_to_MBUS_axi_arcache  ),
        .rv_socket_data_axi_arprot    ( RV_SOCKET_DATA_to_MBUS_axi_arprot   ),
        .rv_socket_data_axi_arqos     ( RV_SOCKET_DATA_to_MBUS_axi_arqos    ),
        .rv_socket_data_axi_arvalid   ( RV_SOCKET_DATA_to_MBUS_axi_arvalid  ),
        .rv_socket_data_axi_arready   ( RV_SOCKET_DATA_to_MBUS_axi_arready  ),
        .rv_socket_data_axi_arregion  ( RV_SOCKET_DATA_to_MBUS_axi_arregion ),
        .rv_socket_data_axi_rid       ( RV_SOCKET_DATA_to_MBUS_axi_rid      ),
        .rv_socket_data_axi_rdata     ( RV_SOCKET_DATA_to_MBUS_axi_rdata    ),
        .rv_socket_data_axi_rresp     ( RV_SOCKET_DATA_to_MBUS_axi_rresp    ),
        .rv_socket_data_axi_rlast     ( RV_SOCKET_DATA_to_MBUS_axi_rlast    ),
        .rv_socket_data_axi_rvalid    ( RV_SOCKET_DATA_to_MBUS_axi_rvalid   ),
        .rv_socket_data_axi_rready    ( RV_SOCKET_DATA_to_MBUS_axi_rready   ),

        // Debug AXI master
        .rv_socket_dbg_master_axi_awid       ( DBG_MASTER_to_MBUS_axi_awid     ),
        .rv_socket_dbg_master_axi_awaddr     ( DBG_MASTER_to_MBUS_axi_awaddr   ),
        .rv_socket_dbg_master_axi_awlen      ( DBG_MASTER_to_MBUS_axi_awlen    ),
        .rv_socket_dbg_master_axi_awsize     ( DBG_MASTER_to_MBUS_axi_awsize   ),
        .rv_socket_dbg_master_axi_awburst    ( DBG_MASTER_to_MBUS_axi_awburst  ),
        .rv_socket_dbg_master_axi_awlock     ( DBG_MASTER_to_MBUS_axi_awlock   ),
        .rv_socket_dbg_master_axi_awcache    ( DBG_MASTER_to_MBUS_axi_awcache  ),
        .rv_socket_dbg_master_axi_awprot     ( DBG_MASTER_to_MBUS_axi_awprot   ),
        .rv_socket_dbg_master_axi_awqos      ( DBG_MASTER_to_MBUS_axi_awqos    ),
        .rv_socket_dbg_master_axi_awvalid    ( DBG_MASTER_to_MBUS_axi_awvalid  ),
        .rv_socket_dbg_master_axi_awready    ( DBG_MASTER_to_MBUS_axi_awready  ),
        .rv_socket_dbg_master_axi_awregion   ( DBG_MASTER_to_MBUS_axi_awregion ),
        .rv_socket_dbg_master_axi_wdata      ( DBG_MASTER_to_MBUS_axi_wdata    ),
        .rv_socket_dbg_master_axi_wstrb      ( DBG_MASTER_to_MBUS_axi_wstrb    ),
        .rv_socket_dbg_master_axi_wlast      ( DBG_MASTER_to_MBUS_axi_wlast    ),
        .rv_socket_dbg_master_axi_wvalid     ( DBG_MASTER_to_MBUS_axi_wvalid   ),
        .rv_socket_dbg_master_axi_wready     ( DBG_MASTER_to_MBUS_axi_wready   ),
        .rv_socket_dbg_master_axi_bid        ( DBG_MASTER_to_MBUS_axi_bid      ),
        .rv_socket_dbg_master_axi_bresp      ( DBG_MASTER_to_MBUS_axi_bresp    ),
        .rv_socket_dbg_master_axi_bvalid     ( DBG_MASTER_to_MBUS_axi_bvalid   ),
        .rv_socket_dbg_master_axi_bready     ( DBG_MASTER_to_MBUS_axi_bready   ),
        .rv_socket_dbg_master_axi_arid       ( DBG_MASTER_to_MBUS_axi_arid     ),
        .rv_socket_dbg_master_axi_araddr     ( DBG_MASTER_to_MBUS_axi_araddr   ),
        .rv_socket_dbg_master_axi_arlen      ( DBG_MASTER_to_MBUS_axi_arlen    ),
        .rv_socket_dbg_master_axi_arsize     ( DBG_MASTER_to_MBUS_axi_arsize   ),
        .rv_socket_dbg_master_axi_arburst    ( DBG_MASTER_to_MBUS_axi_arburst  ),
        .rv_socket_dbg_master_axi_arlock     ( DBG_MASTER_to_MBUS_axi_arlock   ),
        .rv_socket_dbg_master_axi_arcache    ( DBG_MASTER_to_MBUS_axi_arcache  ),
        .rv_socket_dbg_master_axi_arprot     ( DBG_MASTER_to_MBUS_axi_arprot   ),
        .rv_socket_dbg_master_axi_arqos      ( DBG_MASTER_to_MBUS_axi_arqos    ),
        .rv_socket_dbg_master_axi_arvalid    ( DBG_MASTER_to_MBUS_axi_arvalid  ),
        .rv_socket_dbg_master_axi_arready    ( DBG_MASTER_to_MBUS_axi_arready  ),
        .rv_socket_dbg_master_axi_arregion   ( DBG_MASTER_to_MBUS_axi_arregion ),
        .rv_socket_dbg_master_axi_rid        ( DBG_MASTER_to_MBUS_axi_rid      ),
        .rv_socket_dbg_master_axi_rdata      ( DBG_MASTER_to_MBUS_axi_rdata    ),
        .rv_socket_dbg_master_axi_rresp      ( DBG_MASTER_to_MBUS_axi_rresp    ),
        .rv_socket_dbg_master_axi_rlast      ( DBG_MASTER_to_MBUS_axi_rlast    ),
        .rv_socket_dbg_master_axi_rvalid     ( DBG_MASTER_to_MBUS_axi_rvalid   ),
        .rv_socket_dbg_master_axi_rready     ( DBG_MASTER_to_MBUS_axi_rready   ),

        // Debug AXI slave
        .rv_socket_dbg_slave_axi_awid        ( MBUS_to_DM_mem_axi_awid     ),
        .rv_socket_dbg_slave_axi_awaddr      ( MBUS_to_DM_mem_axi_awaddr   ),
        .rv_socket_dbg_slave_axi_awlen       ( MBUS_to_DM_mem_axi_awlen    ),
        .rv_socket_dbg_slave_axi_awsize      ( MBUS_to_DM_mem_axi_awsize   ),
        .rv_socket_dbg_slave_axi_awburst     ( MBUS_to_DM_mem_axi_awburst  ),
        .rv_socket_dbg_slave_axi_awlock      ( MBUS_to_DM_mem_axi_awlock   ),
        .rv_socket_dbg_slave_axi_awcache     ( MBUS_to_DM_mem_axi_awcache  ),
        .rv_socket_dbg_slave_axi_awprot      ( MBUS_to_DM_mem_axi_awprot   ),
        .rv_socket_dbg_slave_axi_awqos       ( MBUS_to_DM_mem_axi_awqos    ),
        .rv_socket_dbg_slave_axi_awvalid     ( MBUS_to_DM_mem_axi_awvalid  ),
        .rv_socket_dbg_slave_axi_awready     ( MBUS_to_DM_mem_axi_awready  ),
        .rv_socket_dbg_slave_axi_awregion    ( MBUS_to_DM_mem_axi_awregion ),
        .rv_socket_dbg_slave_axi_wdata       ( MBUS_to_DM_mem_axi_wdata    ),
        .rv_socket_dbg_slave_axi_wstrb       ( MBUS_to_DM_mem_axi_wstrb    ),
        .rv_socket_dbg_slave_axi_wlast       ( MBUS_to_DM_mem_axi_wlast    ),
        .rv_socket_dbg_slave_axi_wvalid      ( MBUS_to_DM_mem_axi_wvalid   ),
        .rv_socket_dbg_slave_axi_wready      ( MBUS_to_DM_mem_axi_wready   ),
        .rv_socket_dbg_slave_axi_bid         ( MBUS_to_DM_mem_axi_bid      ),
        .rv_socket_dbg_slave_axi_bresp       ( MBUS_to_DM_mem_axi_bresp    ),
        .rv_socket_dbg_slave_axi_bvalid      ( MBUS_to_DM_mem_axi_bvalid   ),
        .rv_socket_dbg_slave_axi_bready      ( MBUS_to_DM_mem_axi_bready   ),
        .rv_socket_dbg_slave_axi_arid        ( MBUS_to_DM_mem_axi_arid     ),
        .rv_socket_dbg_slave_axi_araddr      ( MBUS_to_DM_mem_axi_araddr   ),
        .rv_socket_dbg_slave_axi_arlen       ( MBUS_to_DM_mem_axi_arlen    ),
        .rv_socket_dbg_slave_axi_arsize      ( MBUS_to_DM_mem_axi_arsize   ),
        .rv_socket_dbg_slave_axi_arburst     ( MBUS_to_DM_mem_axi_arburst  ),
        .rv_socket_dbg_slave_axi_arlock      ( MBUS_to_DM_mem_axi_arlock   ),
        .rv_socket_dbg_slave_axi_arcache     ( MBUS_to_DM_mem_axi_arcache  ),
        .rv_socket_dbg_slave_axi_arprot      ( MBUS_to_DM_mem_axi_arprot   ),
        .rv_socket_dbg_slave_axi_arqos       ( MBUS_to_DM_mem_axi_arqos    ),
        .rv_socket_dbg_slave_axi_arvalid     ( MBUS_to_DM_mem_axi_arvalid  ),
        .rv_socket_dbg_slave_axi_arready     ( MBUS_to_DM_mem_axi_arready  ),
        .rv_socket_dbg_slave_axi_arregion    ( MBUS_to_DM_mem_axi_arregion ),
        .rv_socket_dbg_slave_axi_rid         ( MBUS_to_DM_mem_axi_rid      ),
        .rv_socket_dbg_slave_axi_rdata       ( MBUS_to_DM_mem_axi_rdata    ),
        .rv_socket_dbg_slave_axi_rresp       ( MBUS_to_DM_mem_axi_rresp    ),
        .rv_socket_dbg_slave_axi_rlast       ( MBUS_to_DM_mem_axi_rlast    ),
        .rv_socket_dbg_slave_axi_rvalid      ( MBUS_to_DM_mem_axi_rvalid   ),
        .rv_socket_dbg_slave_axi_rready      ( MBUS_to_DM_mem_axi_rready   )
    );

    ////////////////
    // AXI slaves //
    ////////////////

    // Main memory
    xlnx_blk_mem_gen_0 main_memory_u (
        .rsta_busy      ( /* open */                ), // output wire rsta_busy
        .rstb_busy      ( /* open */                ), // output wire rstb_busy
        .s_aclk         ( main_clk                  ), // input wire s_aclk
        .s_aresetn      ( main_rstn                 ), // input wire s_aresetn
        .s_axi_awid     ( MBUS_to_BRAM_axi_awid     ), // input wire [3 : 0] s_axi_awid
        .s_axi_awaddr   ( MBUS_to_BRAM_axi_awaddr   ), // input wire [31 : 0] s_axi_awaddr
        .s_axi_awlen    ( MBUS_to_BRAM_axi_awlen    ), // input wire [7 : 0] s_axi_awlen
        .s_axi_awsize   ( MBUS_to_BRAM_axi_awsize   ), // input wire [2 : 0] s_axi_awsize
        .s_axi_awburst  ( MBUS_to_BRAM_axi_awburst  ), // input wire [1 : 0] s_axi_awburst
        .s_axi_awvalid  ( MBUS_to_BRAM_axi_awvalid  ), // input wire s_axi_awvalid
        .s_axi_awready  ( MBUS_to_BRAM_axi_awready  ), // output wire s_axi_awready
        .s_axi_wdata    ( MBUS_to_BRAM_axi_wdata    ), // input wire [31 : 0] s_axi_wdata
        .s_axi_wstrb    ( MBUS_to_BRAM_axi_wstrb    ), // input wire [3 : 0] s_axi_wstrb
        .s_axi_wlast    ( MBUS_to_BRAM_axi_wlast    ), // input wire s_axi_wlast
        .s_axi_wvalid   ( MBUS_to_BRAM_axi_wvalid   ), // input wire s_axi_wvalid
        .s_axi_wready   ( MBUS_to_BRAM_axi_wready   ), // output wire s_axi_wready
        .s_axi_bid      ( MBUS_to_BRAM_axi_bid      ), // output wire [3 : 0] s_axi_bid
        .s_axi_bresp    ( MBUS_to_BRAM_axi_bresp    ), // output wire [1 : 0] s_axi_bresp
        .s_axi_bvalid   ( MBUS_to_BRAM_axi_bvalid   ), // output wire s_axi_bvalid
        .s_axi_bready   ( MBUS_to_BRAM_axi_bready   ), // input wire s_axi_bready
        .s_axi_arid     ( MBUS_to_BRAM_axi_arid     ), // input wire [3 : 0] s_axi_arid
        .s_axi_araddr   ( MBUS_to_BRAM_axi_araddr   ), // input wire [31 : 0] s_axi_araddr
        .s_axi_arlen    ( MBUS_to_BRAM_axi_arlen    ), // input wire [7 : 0] s_axi_arlen
        .s_axi_arsize   ( MBUS_to_BRAM_axi_arsize   ), // input wire [2 : 0] s_axi_arsize
        .s_axi_arburst  ( MBUS_to_BRAM_axi_arburst  ), // input wire [1 : 0] s_axi_arburst
        .s_axi_arvalid  ( MBUS_to_BRAM_axi_arvalid  ), // input wire s_axi_arvalid
        .s_axi_arready  ( MBUS_to_BRAM_axi_arready  ), // output wire s_axi_arready
        .s_axi_rid      ( MBUS_to_BRAM_axi_rid      ), // output wire [3 : 0] s_axi_rid
        .s_axi_rdata    ( MBUS_to_BRAM_axi_rdata    ), // output wire [31 : 0] s_axi_rdata
        .s_axi_rresp    ( MBUS_to_BRAM_axi_rresp    ), // output wire [1 : 0] s_axi_rresp
        .s_axi_rlast    ( MBUS_to_BRAM_axi_rlast    ), // output wire s_axi_rlast
        .s_axi_rvalid   ( MBUS_to_BRAM_axi_rvalid   ), // output wire s_axi_rvalid
        .s_axi_rready   ( MBUS_to_BRAM_axi_rready   )  // input wire s_axi_rready
    );

    // Platform-Level Interrupt Controller (PLIC)
    logic [31:0] plic_int_line;
    logic plic_int_irq_o;

    always_comb begin : system_interrupts

        // Default non-assigned lines
        plic_int_line = '0;
        rv_socket_interrupt_line = '0;

        // Mapping PLIC input interrupts (only from pbus at the moment)
        // Mapping is static (refer to uninasoc_pkg.sv)
        plic_int_line[PLIC_RESERVED_INTERRUPT]  = 1'b0;
        plic_int_line[PLIC_GPIOIN_INTERRUPT]    = pbus_int_line[PBUS_GPIOIN_INTERRUPT];
        plic_int_line[PLIC_TIM0_INTERRUPT]      = pbus_int_line[PBUS_TIM0_INTERRUPT];
        plic_int_line[PLIC_TIM1_INTERRUPT]      = pbus_int_line[PBUS_TIM1_INTERRUPT];
        plic_int_line[PLIC_UART_INTERRUPT]      = pbus_int_line[PBUS_UART_INTERRUPT];

        // Map system-interrupts pins to socket interrupts
        rv_socket_interrupt_line[CORE_EXT_INTERRUPT] = plic_int_irq_o;

    end : system_interrupts

    plic_wrapper #(
        .LOCAL_DATA_WIDTH   ( MBUS_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH   ( MBUS_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH     ( MBUS_ID_WIDTH   )
    ) plic_wrapper_u (
        .clk_i          ( main_clk                      ), // input wire s_axi_aclk
        .rst_ni         ( main_rstn                     ), // input wire s_axi_aresetn
        // AXI4 slave port (from xbar)
        .intr_src_i     ( plic_int_line                 ), // Input interrupt lines (Sources)
        .irq_o          ( plic_int_irq_o                ), // Output Interrupts (Targets -> Socket)
        .s_axi_awid     ( MBUS_to_PLIC_axi_awid         ), // input wire [1 : 0] s_axi_awid
        .s_axi_awaddr   ( MBUS_to_PLIC_axi_awaddr       ), // input wire [25 : 0] s_axi_awaddr
        .s_axi_awlen    ( MBUS_to_PLIC_axi_awlen        ), // input wire [7 : 0] s_axi_awlen
        .s_axi_awsize   ( MBUS_to_PLIC_axi_awsize       ), // input wire [2 : 0] s_axi_awsize
        .s_axi_awburst  ( MBUS_to_PLIC_axi_awburst      ), // input wire [1 : 0] s_axi_awburst
        .s_axi_awlock   ( MBUS_to_PLIC_axi_awlock       ), // input wire [0 : 0] s_axi_awlock
        .s_axi_awcache  ( MBUS_to_PLIC_axi_awcache      ), // input wire [3 : 0] s_axi_awcache
        .s_axi_awprot   ( MBUS_to_PLIC_axi_awprot       ), // input wire [2 : 0] s_axi_awprot
        .s_axi_awregion ( MBUS_to_PLIC_axi_awregion     ), // input wire [3 : 0] s_axi_awregion
        .s_axi_awqos    ( MBUS_to_PLIC_axi_awqos        ), // input wire [3 : 0] s_axi_awqos
        .s_axi_awvalid  ( MBUS_to_PLIC_axi_awvalid      ), // input wire s_axi_awvalid
        .s_axi_awready  ( MBUS_to_PLIC_axi_awready      ), // output wire s_axi_awready
        .s_axi_wdata    ( MBUS_to_PLIC_axi_wdata        ), // input wire [31 : 0] s_axi_wdata
        .s_axi_wstrb    ( MBUS_to_PLIC_axi_wstrb        ), // input wire [3 : 0] s_axi_wstrb
        .s_axi_wlast    ( MBUS_to_PLIC_axi_wlast        ), // input wire s_axi_wlast
        .s_axi_wvalid   ( MBUS_to_PLIC_axi_wvalid       ), // input wire s_axi_wvalid
        .s_axi_wready   ( MBUS_to_PLIC_axi_wready       ), // output wire s_axi_wready
        .s_axi_bid      ( MBUS_to_PLIC_axi_bid          ), // output wire [1 : 0] s_axi_bid
        .s_axi_bresp    ( MBUS_to_PLIC_axi_bresp        ), // output wire [1 : 0] s_axi_bresp
        .s_axi_bvalid   ( MBUS_to_PLIC_axi_bvalid       ), // output wire s_axi_bvalid
        .s_axi_bready   ( MBUS_to_PLIC_axi_bready       ), // input wire s_axi_bready
        .s_axi_arid     ( MBUS_to_PLIC_axi_arid         ), // input wire [1 : 0] s_axi_arid
        .s_axi_araddr   ( MBUS_to_PLIC_axi_araddr       ), // input wire [25 : 0] s_axi_araddr
        .s_axi_arlen    ( MBUS_to_PLIC_axi_arlen        ), // input wire [7 : 0] s_axi_arlen
        .s_axi_arsize   ( MBUS_to_PLIC_axi_arsize       ), // input wire [2 : 0] s_axi_arsize
        .s_axi_arburst  ( MBUS_to_PLIC_axi_arburst      ), // input wire [1 : 0] s_axi_arburst
        .s_axi_arlock   ( MBUS_to_PLIC_axi_arlock       ), // input wire [0 : 0] s_axi_arlock
        .s_axi_arcache  ( MBUS_to_PLIC_axi_arcache      ), // input wire [3 : 0] s_axi_arcache
        .s_axi_arprot   ( MBUS_to_PLIC_axi_arprot       ), // input wire [2 : 0] s_axi_arprot
        .s_axi_arregion ( MBUS_to_PLIC_axi_arregion     ), // input wire [3 : 0] s_axi_arregion
        .s_axi_arqos    ( MBUS_to_PLIC_axi_arqos        ), // input wire [3 : 0] s_axi_arqos
        .s_axi_arvalid  ( MBUS_to_PLIC_axi_arvalid      ), // input wire s_axi_arvalid
        .s_axi_arready  ( MBUS_to_PLIC_axi_arready      ), // output wire s_axi_arready
        .s_axi_rid      ( MBUS_to_PLIC_axi_rid          ), // output wire [1 : 0] s_axi_rid
        .s_axi_rdata    ( MBUS_to_PLIC_axi_rdata        ), // output wire [31 : 0] s_axi_rdata
        .s_axi_rresp    ( MBUS_to_PLIC_axi_rresp        ), // output wire [1 : 0] s_axi_rresp
        .s_axi_rlast    ( MBUS_to_PLIC_axi_rlast        ), // output wire s_axi_rlast
        .s_axi_rvalid   ( MBUS_to_PLIC_axi_rvalid       ), // output wire s_axi_rvalid
        .s_axi_rready   ( MBUS_to_PLIC_axi_rready       )
    );

    ////////////////////
    // PERIPHERAL BUS //
    ////////////////////

    peripheral_bus # (

        .LOCAL_DATA_WIDTH   ( PBUS_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH   ( PBUS_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH     ( PBUS_ID_WIDTH   )

        ) peripheral_bus_u (

        .main_clock_i   ( main_clk    ),
        .main_reset_ni  ( main_rstn   ),
        .PBUS_clock_i   ( PBUS_clk    ),
        .PBUS_reset_ni  ( PBUS_rstn   ),

        // EMBEDDED ONLY
        .uart_rx_i      ( uart_rx_i      ),
        .uart_tx_o      ( uart_tx_o      ),
        .gpio_out_o     ( gpio_out_o     ),
        .gpio_in_i      ( gpio_in_i      ),

        .int_o          ( pbus_int_line  ),

        .s_axi_awid     ( MBUS_to_PBUS_axi_awid     ),
        .s_axi_awaddr   ( MBUS_to_PBUS_axi_awaddr   ),
        .s_axi_awlen    ( MBUS_to_PBUS_axi_awlen    ),
        .s_axi_awsize   ( MBUS_to_PBUS_axi_awsize   ),
        .s_axi_awburst  ( MBUS_to_PBUS_axi_awburst  ),
        .s_axi_awlock   ( MBUS_to_PBUS_axi_awlock   ),
        .s_axi_awcache  ( MBUS_to_PBUS_axi_awcache  ),
        .s_axi_awprot   ( MBUS_to_PBUS_axi_awprot   ),
        .s_axi_awregion ( MBUS_to_PBUS_axi_awregion ),
        .s_axi_awqos    ( MBUS_to_PBUS_axi_awqos    ),
        .s_axi_awvalid  ( MBUS_to_PBUS_axi_awvalid  ),
        .s_axi_awready  ( MBUS_to_PBUS_axi_awready  ),
        .s_axi_wdata    ( MBUS_to_PBUS_axi_wdata    ),
        .s_axi_wstrb    ( MBUS_to_PBUS_axi_wstrb    ),
        .s_axi_wlast    ( MBUS_to_PBUS_axi_wlast    ),
        .s_axi_wvalid   ( MBUS_to_PBUS_axi_wvalid   ),
        .s_axi_wready   ( MBUS_to_PBUS_axi_wready   ),
        .s_axi_bid      ( MBUS_to_PBUS_axi_bid      ),
        .s_axi_bresp    ( MBUS_to_PBUS_axi_bresp    ),
        .s_axi_bvalid   ( MBUS_to_PBUS_axi_bvalid   ),
        .s_axi_bready   ( MBUS_to_PBUS_axi_bready   ),
        .s_axi_arid     ( MBUS_to_PBUS_axi_arid     ),
        .s_axi_araddr   ( MBUS_to_PBUS_axi_araddr   ),
        .s_axi_arlen    ( MBUS_to_PBUS_axi_arlen    ),
        .s_axi_arsize   ( MBUS_to_PBUS_axi_arsize   ),
        .s_axi_arburst  ( MBUS_to_PBUS_axi_arburst  ),
        .s_axi_arlock   ( MBUS_to_PBUS_axi_arlock   ),
        .s_axi_arcache  ( MBUS_to_PBUS_axi_arcache  ),
        .s_axi_arprot   ( MBUS_to_PBUS_axi_arprot   ),
        .s_axi_arregion ( MBUS_to_PBUS_axi_arregion ),
        .s_axi_arqos    ( MBUS_to_PBUS_axi_arqos    ),
        .s_axi_arvalid  ( MBUS_to_PBUS_axi_arvalid  ),
        .s_axi_arready  ( MBUS_to_PBUS_axi_arready  ),
        .s_axi_rid      ( MBUS_to_PBUS_axi_rid      ),
        .s_axi_rdata    ( MBUS_to_PBUS_axi_rdata    ),
        .s_axi_rresp    ( MBUS_to_PBUS_axi_rresp    ),
        .s_axi_rlast    ( MBUS_to_PBUS_axi_rlast    ),
        .s_axi_rvalid   ( MBUS_to_PBUS_axi_rvalid   ),
        .s_axi_rready   ( MBUS_to_PBUS_axi_rready   )
    );

// In HPC profile
`ifdef HPC

    // DDR4 Channel 0
    ddr4_channel_wrapper # (
        .ENABLE_CACHE       ( 1               ), // Always enabled for DDR4CH0
        .LOCAL_DATA_WIDTH   ( MBUS_DATA_WIDTH ),
        .LOCAL_ADDR_WIDTH   ( MBUS_ADDR_WIDTH ),
        .LOCAL_ID_WIDTH     ( MBUS_ID_WIDTH   )
    ) ddr4_channel_0_wrapper_u (
        .clock_i              ( main_clk          ),
        .reset_ni             ( main_rstn         ),
        // DDR4 differential clock
        .clk_300mhz_0_p_i     ( clk_300mhz_0_p_i  ),
        .clk_300mhz_0_n_i     ( clk_300mhz_0_n_i  ),

        // Connect DDR4 channel 0
        .cx_ddr4_adr          ( c0_ddr4_adr       ),
        .cx_ddr4_ba           ( c0_ddr4_ba        ),
        .cx_ddr4_cke          ( c0_ddr4_cke       ),
        .cx_ddr4_cs_n         ( c0_ddr4_cs_n      ),
        .cx_ddr4_dq           ( c0_ddr4_dq        ),
        .cx_ddr4_dqs_t        ( c0_ddr4_dqs_t     ),
        .cx_ddr4_dqs_c        ( c0_ddr4_dqs_c     ),
        .cx_ddr4_odt          ( c0_ddr4_odt       ),
        .cx_ddr4_par          ( c0_ddr4_par       ),
        .cx_ddr4_bg           ( c0_ddr4_bg        ),
        .cx_ddr4_act_n        ( c0_ddr4_act_n     ),
        .cx_ddr4_reset_n      ( c0_ddr4_reset_n   ),
        .cx_ddr4_ck_t         ( c0_ddr4_ck_t      ),
        .cx_ddr4_ck_c         ( c0_ddr4_ck_c      ),

        // AXILITE interface - for ECC status and control - not connected
        .s_ctrl_axilite_awvalid  ( 1'b0  ),
        .s_ctrl_axilite_awready  (       ),
        .s_ctrl_axilite_awaddr   ( 32'd0 ),
        .s_ctrl_axilite_wvalid   ( 1'b0  ),
        .s_ctrl_axilite_wready   (       ),
        .s_ctrl_axilite_wdata    ( 32'd0 ),
        .s_ctrl_axilite_bvalid   (       ),
        .s_ctrl_axilite_bready   ( 1'b1  ),
        .s_ctrl_axilite_bresp    (       ),
        .s_ctrl_axilite_arvalid  ( 1'b0  ),
        .s_ctrl_axilite_arready  (       ),
        .s_ctrl_axilite_araddr   ( 31'd0 ),
        .s_ctrl_axilite_rvalid   (       ),
        .s_ctrl_axilite_rready   ( 1'b1  ),
        .s_ctrl_axilite_rdata    (       ),
        .s_ctrl_axilite_rresp    (       ),

        // Slave interface
        .s_axi_awid           ( MBUS_to_DDR_axi_awid     ),
        .s_axi_awaddr         ( MBUS_to_DDR_axi_awaddr   ),
        .s_axi_awlen          ( MBUS_to_DDR_axi_awlen    ),
        .s_axi_awsize         ( MBUS_to_DDR_axi_awsize   ),
        .s_axi_awburst        ( MBUS_to_DDR_axi_awburst  ),
        .s_axi_awlock         ( MBUS_to_DDR_axi_awlock   ),
        .s_axi_awcache        ( MBUS_to_DDR_axi_awcache  ),
        .s_axi_awprot         ( MBUS_to_DDR_axi_awprot   ),
        .s_axi_awregion       ( MBUS_to_DDR_axi_awregion ),
        .s_axi_awqos          ( MBUS_to_DDR_axi_awqos    ),
        .s_axi_awvalid        ( MBUS_to_DDR_axi_awvalid  ),
        .s_axi_awready        ( MBUS_to_DDR_axi_awready  ),
        .s_axi_wdata          ( MBUS_to_DDR_axi_wdata    ),
        .s_axi_wstrb          ( MBUS_to_DDR_axi_wstrb    ),
        .s_axi_wlast          ( MBUS_to_DDR_axi_wlast    ),
        .s_axi_wvalid         ( MBUS_to_DDR_axi_wvalid   ),
        .s_axi_wready         ( MBUS_to_DDR_axi_wready   ),
        .s_axi_bid            ( MBUS_to_DDR_axi_bid      ),
        .s_axi_bresp          ( MBUS_to_DDR_axi_bresp    ),
        .s_axi_bvalid         ( MBUS_to_DDR_axi_bvalid   ),
        .s_axi_bready         ( MBUS_to_DDR_axi_bready   ),
        .s_axi_arid           ( MBUS_to_DDR_axi_arid     ),
        .s_axi_araddr         ( MBUS_to_DDR_axi_araddr   ),
        .s_axi_arlen          ( MBUS_to_DDR_axi_arlen    ),
        .s_axi_arsize         ( MBUS_to_DDR_axi_arsize   ),
        .s_axi_arburst        ( MBUS_to_DDR_axi_arburst  ),
        .s_axi_arlock         ( MBUS_to_DDR_axi_arlock   ),
        .s_axi_arcache        ( MBUS_to_DDR_axi_arcache  ),
        .s_axi_arprot         ( MBUS_to_DDR_axi_arprot   ),
        .s_axi_arregion       ( MBUS_to_DDR_axi_arregion ),
        .s_axi_arqos          ( MBUS_to_DDR_axi_arqos    ),
        .s_axi_arvalid        ( MBUS_to_DDR_axi_arvalid  ),
        .s_axi_arready        ( MBUS_to_DDR_axi_arready  ),
        .s_axi_rid            ( MBUS_to_DDR_axi_rid      ),
        .s_axi_rdata          ( MBUS_to_DDR_axi_rdata    ),
        .s_axi_rresp          ( MBUS_to_DDR_axi_rresp    ),
        .s_axi_rlast          ( MBUS_to_DDR_axi_rlast    ),
        .s_axi_rvalid         ( MBUS_to_DDR_axi_rvalid   ),
        .s_axi_rready         ( MBUS_to_DDR_axi_rready   )
    );

    //////////
    // HBUS //
    //////////

    // TODO: HBUS is currently broken, to be fixed in the next issues
    // TODO: No HBUS accelerators for now, just sink the s_acc interface for now
    /*`DECLARE_AXI_BUS(s_acc_HBUS, HBUS_DATA_WIDTH, HBUS_ADDR_WIDTH, HBUS_ID_WIDTH)
    `SINK_AXI_MASTER_INTERFACE(s_acc_HBUS)

    highperformance_bus # (
        .HBUS_DATA_WIDTH  ( HBUS_DATA_WIDTH ),
        .HBUS_ADDR_WIDTH  ( HBUS_ADDR_WIDTH ),
        .HBUS_ID_WIDTH    ( HBUS_ID_WIDTH   ),
        .MBUS_DATA_WIDTH  ( MBUS_DATA_WIDTH ),
        .MBUS_ADDR_WIDTH  ( MBUS_ADDR_WIDTH ),
        .MBUS_ID_WIDTH    ( MBUS_ID_WIDTH   ),
        // TODO: these are fixed for now
        .NUM_ACC_MASTERS  ( 1 ),
        .NUM_DDR_CHANNELS ( 1 ),
        .NUM_HBM_CHANNELS ( 0 )
    ) highperformance_bus_u (
        // Mian domain clock and reset
        .main_clock_i   ( main_clk  ),
        .main_reset_ni  ( main_rstn ),
        // From MBUS
        .s_MBUS_axi_awid     ( MBUS_to_HBUS_axi_awid     ),
        .s_MBUS_axi_awaddr   ( MBUS_to_HBUS_axi_awaddr   ),
        .s_MBUS_axi_awlen    ( MBUS_to_HBUS_axi_awlen    ),
        .s_MBUS_axi_awsize   ( MBUS_to_HBUS_axi_awsize   ),
        .s_MBUS_axi_awburst  ( MBUS_to_HBUS_axi_awburst  ),
        .s_MBUS_axi_awlock   ( MBUS_to_HBUS_axi_awlock   ),
        .s_MBUS_axi_awcache  ( MBUS_to_HBUS_axi_awcache  ),
        .s_MBUS_axi_awprot   ( MBUS_to_HBUS_axi_awprot   ),
        .s_MBUS_axi_awregion ( MBUS_to_HBUS_axi_awregion ),
        .s_MBUS_axi_awqos    ( MBUS_to_HBUS_axi_awqos    ),
        .s_MBUS_axi_awvalid  ( MBUS_to_HBUS_axi_awvalid  ),
        .s_MBUS_axi_awready  ( MBUS_to_HBUS_axi_awready  ),
        .s_MBUS_axi_wdata    ( MBUS_to_HBUS_axi_wdata    ),
        .s_MBUS_axi_wstrb    ( MBUS_to_HBUS_axi_wstrb    ),
        .s_MBUS_axi_wlast    ( MBUS_to_HBUS_axi_wlast    ),
        .s_MBUS_axi_wvalid   ( MBUS_to_HBUS_axi_wvalid   ),
        .s_MBUS_axi_wready   ( MBUS_to_HBUS_axi_wready   ),
        .s_MBUS_axi_bid      ( MBUS_to_HBUS_axi_bid      ),
        .s_MBUS_axi_bresp    ( MBUS_to_HBUS_axi_bresp    ),
        .s_MBUS_axi_bvalid   ( MBUS_to_HBUS_axi_bvalid   ),
        .s_MBUS_axi_bready   ( MBUS_to_HBUS_axi_bready   ),
        .s_MBUS_axi_arid     ( MBUS_to_HBUS_axi_arid     ),
        .s_MBUS_axi_araddr   ( MBUS_to_HBUS_axi_araddr   ),
        .s_MBUS_axi_arlen    ( MBUS_to_HBUS_axi_arlen    ),
        .s_MBUS_axi_arsize   ( MBUS_to_HBUS_axi_arsize   ),
        .s_MBUS_axi_arburst  ( MBUS_to_HBUS_axi_arburst  ),
        .s_MBUS_axi_arlock   ( MBUS_to_HBUS_axi_arlock   ),
        .s_MBUS_axi_arcache  ( MBUS_to_HBUS_axi_arcache  ),
        .s_MBUS_axi_arprot   ( MBUS_to_HBUS_axi_arprot   ),
        .s_MBUS_axi_arregion ( MBUS_to_HBUS_axi_arregion ),
        .s_MBUS_axi_arqos    ( MBUS_to_HBUS_axi_arqos    ),
        .s_MBUS_axi_arvalid  ( MBUS_to_HBUS_axi_arvalid  ),
        .s_MBUS_axi_arready  ( MBUS_to_HBUS_axi_arready  ),
        .s_MBUS_axi_rid      ( MBUS_to_HBUS_axi_rid      ),
        .s_MBUS_axi_rdata    ( MBUS_to_HBUS_axi_rdata    ),
        .s_MBUS_axi_rresp    ( MBUS_to_HBUS_axi_rresp    ),
        .s_MBUS_axi_rlast    ( MBUS_to_HBUS_axi_rlast    ),
        .s_MBUS_axi_rvalid   ( MBUS_to_HBUS_axi_rvalid   ),
        .s_MBUS_axi_rready   ( MBUS_to_HBUS_axi_rready   ),
        // To MBUS
        .m_MBUS_axi_awid     ( HBUS_to_MBUS_axi_awid     ),
        .m_MBUS_axi_awaddr   ( HBUS_to_MBUS_axi_awaddr   ),
        .m_MBUS_axi_awlen    ( HBUS_to_MBUS_axi_awlen    ),
        .m_MBUS_axi_awsize   ( HBUS_to_MBUS_axi_awsize   ),
        .m_MBUS_axi_awburst  ( HBUS_to_MBUS_axi_awburst  ),
        .m_MBUS_axi_awlock   ( HBUS_to_MBUS_axi_awlock   ),
        .m_MBUS_axi_awcache  ( HBUS_to_MBUS_axi_awcache  ),
        .m_MBUS_axi_awprot   ( HBUS_to_MBUS_axi_awprot   ),
        .m_MBUS_axi_awregion ( HBUS_to_MBUS_axi_awregion ),
        .m_MBUS_axi_awqos    ( HBUS_to_MBUS_axi_awqos    ),
        .m_MBUS_axi_awvalid  ( HBUS_to_MBUS_axi_awvalid  ),
        .m_MBUS_axi_awready  ( HBUS_to_MBUS_axi_awready  ),
        .m_MBUS_axi_wdata    ( HBUS_to_MBUS_axi_wdata    ),
        .m_MBUS_axi_wstrb    ( HBUS_to_MBUS_axi_wstrb    ),
        .m_MBUS_axi_wlast    ( HBUS_to_MBUS_axi_wlast    ),
        .m_MBUS_axi_wvalid   ( HBUS_to_MBUS_axi_wvalid   ),
        .m_MBUS_axi_wready   ( HBUS_to_MBUS_axi_wready   ),
        .m_MBUS_axi_bid      ( HBUS_to_MBUS_axi_bid      ),
        .m_MBUS_axi_bresp    ( HBUS_to_MBUS_axi_bresp    ),
        .m_MBUS_axi_bvalid   ( HBUS_to_MBUS_axi_bvalid   ),
        .m_MBUS_axi_bready   ( HBUS_to_MBUS_axi_bready   ),
        .m_MBUS_axi_arid     ( HBUS_to_MBUS_axi_arid     ),
        .m_MBUS_axi_araddr   ( HBUS_to_MBUS_axi_araddr   ),
        .m_MBUS_axi_arlen    ( HBUS_to_MBUS_axi_arlen    ),
        .m_MBUS_axi_arsize   ( HBUS_to_MBUS_axi_arsize   ),
        .m_MBUS_axi_arburst  ( HBUS_to_MBUS_axi_arburst  ),
        .m_MBUS_axi_arlock   ( HBUS_to_MBUS_axi_arlock   ),
        .m_MBUS_axi_arcache  ( HBUS_to_MBUS_axi_arcache  ),
        .m_MBUS_axi_arprot   ( HBUS_to_MBUS_axi_arprot   ),
        .m_MBUS_axi_arregion ( HBUS_to_MBUS_axi_arregion ),
        .m_MBUS_axi_arqos    ( HBUS_to_MBUS_axi_arqos    ),
        .m_MBUS_axi_arvalid  ( HBUS_to_MBUS_axi_arvalid  ),
        .m_MBUS_axi_arready  ( HBUS_to_MBUS_axi_arready  ),
        .m_MBUS_axi_rid      ( HBUS_to_MBUS_axi_rid      ),
        .m_MBUS_axi_rdata    ( HBUS_to_MBUS_axi_rdata    ),
        .m_MBUS_axi_rresp    ( HBUS_to_MBUS_axi_rresp    ),
        .m_MBUS_axi_rlast    ( HBUS_to_MBUS_axi_rlast    ),
        .m_MBUS_axi_rvalid   ( HBUS_to_MBUS_axi_rvalid   ),
        .m_MBUS_axi_rready   ( HBUS_to_MBUS_axi_rready   ),
        // From Accelerator(s)
        // NOTE: just one for now
        // TODO: add a CONCAT to support multiple ports
        .s_acc_axi_awid     ( s_acc_HBUS_axi_awid     ),
        .s_acc_axi_awaddr   ( s_acc_HBUS_axi_awaddr   ),
        .s_acc_axi_awlen    ( s_acc_HBUS_axi_awlen    ),
        .s_acc_axi_awsize   ( s_acc_HBUS_axi_awsize   ),
        .s_acc_axi_awburst  ( s_acc_HBUS_axi_awburst  ),
        .s_acc_axi_awlock   ( s_acc_HBUS_axi_awlock   ),
        .s_acc_axi_awcache  ( s_acc_HBUS_axi_awcache  ),
        .s_acc_axi_awprot   ( s_acc_HBUS_axi_awprot   ),
        .s_acc_axi_awregion ( s_acc_HBUS_axi_awregion ),
        .s_acc_axi_awqos    ( s_acc_HBUS_axi_awqos    ),
        .s_acc_axi_awvalid  ( s_acc_HBUS_axi_awvalid  ),
        .s_acc_axi_awready  ( s_acc_HBUS_axi_awready  ),
        .s_acc_axi_wdata    ( s_acc_HBUS_axi_wdata    ),
        .s_acc_axi_wstrb    ( s_acc_HBUS_axi_wstrb    ),
        .s_acc_axi_wlast    ( s_acc_HBUS_axi_wlast    ),
        .s_acc_axi_wvalid   ( s_acc_HBUS_axi_wvalid   ),
        .s_acc_axi_wready   ( s_acc_HBUS_axi_wready   ),
        .s_acc_axi_bid      ( s_acc_HBUS_axi_bid      ),
        .s_acc_axi_bresp    ( s_acc_HBUS_axi_bresp    ),
        .s_acc_axi_bvalid   ( s_acc_HBUS_axi_bvalid   ),
        .s_acc_axi_bready   ( s_acc_HBUS_axi_bready   ),
        .s_acc_axi_arid     ( s_acc_HBUS_axi_arid     ),
        .s_acc_axi_araddr   ( s_acc_HBUS_axi_araddr   ),
        .s_acc_axi_arlen    ( s_acc_HBUS_axi_arlen    ),
        .s_acc_axi_arsize   ( s_acc_HBUS_axi_arsize   ),
        .s_acc_axi_arburst  ( s_acc_HBUS_axi_arburst  ),
        .s_acc_axi_arlock   ( s_acc_HBUS_axi_arlock   ),
        .s_acc_axi_arcache  ( s_acc_HBUS_axi_arcache  ),
        .s_acc_axi_arprot   ( s_acc_HBUS_axi_arprot   ),
        .s_acc_axi_arregion ( s_acc_HBUS_axi_arregion ),
        .s_acc_axi_arqos    ( s_acc_HBUS_axi_arqos    ),
        .s_acc_axi_arvalid  ( s_acc_HBUS_axi_arvalid  ),
        .s_acc_axi_arready  ( s_acc_HBUS_axi_arready  ),
        .s_acc_axi_rid      ( s_acc_HBUS_axi_rid      ),
        .s_acc_axi_rdata    ( s_acc_HBUS_axi_rdata    ),
        .s_acc_axi_rresp    ( s_acc_HBUS_axi_rresp    ),
        .s_acc_axi_rlast    ( s_acc_HBUS_axi_rlast    ),
        .s_acc_axi_rvalid   ( s_acc_HBUS_axi_rvalid   ),
        .s_acc_axi_rready   ( s_acc_HBUS_axi_rready   ),

        // DDR4 differential clock
        .clk_300mhz_0_p_i     ( clk_300mhz_0_p_i  ),
        .clk_300mhz_0_n_i     ( clk_300mhz_0_n_i  ),
        // DDR4 user clock and reset
        .clk_300MHz_o         ( clk_300MHz        ),
        .rstn_300MHz_o        ( rstn_300MHz       ),
        // Connect DDR4 channel 0
        .cx_ddr4_adr          ( c0_ddr4_adr       ),
        .cx_ddr4_ba           ( c0_ddr4_ba        ),
        .cx_ddr4_cke          ( c0_ddr4_cke       ),
        .cx_ddr4_cs_n         ( c0_ddr4_cs_n      ),
        .cx_ddr4_dq           ( c0_ddr4_dq        ),
        .cx_ddr4_dqs_t        ( c0_ddr4_dqs_t     ),
        .cx_ddr4_dqs_c        ( c0_ddr4_dqs_c     ),
        .cx_ddr4_odt          ( c0_ddr4_odt       ),
        .cx_ddr4_par          ( c0_ddr4_par       ),
        .cx_ddr4_bg           ( c0_ddr4_bg        ),
        .cx_ddr4_act_n        ( c0_ddr4_act_n     ),
        .cx_ddr4_reset_n      ( c0_ddr4_reset_n   ),
        .cx_ddr4_ck_t         ( c0_ddr4_ck_t      ),
        .cx_ddr4_ck_c         ( c0_ddr4_ck_c      ),

        // AXILITE interface - for ECC status and control - not connected
        .s_ctrl_axilite_awvalid  ( 1'b0  ),
        .s_ctrl_axilite_awready  (       ),
        .s_ctrl_axilite_awaddr   ( '0    ),
        .s_ctrl_axilite_wvalid   ( 1'b0  ),
        .s_ctrl_axilite_wready   (       ),
        .s_ctrl_axilite_wdata    ( '0    ),
        .s_ctrl_axilite_bvalid   (       ),
        .s_ctrl_axilite_bready   ( 1'b1  ),
        .s_ctrl_axilite_bresp    (       ),
        .s_ctrl_axilite_arvalid  ( 1'b0  ),
        .s_ctrl_axilite_arready  (       ),
        .s_ctrl_axilite_araddr   ( '0    ),
        .s_ctrl_axilite_rvalid   (       ),
        .s_ctrl_axilite_rready   ( 1'b1  ),
        .s_ctrl_axilite_rdata    (       ),
        .s_ctrl_axilite_rresp    (       ),
        .s_ctrl_axilite_arprot   ( '0    ),
        .s_ctrl_axilite_wstrb    ( '0    ),
        .s_ctrl_axilite_awprot   ( '0    )
    );*/

`endif // HPC


endmodule : uninasoc
