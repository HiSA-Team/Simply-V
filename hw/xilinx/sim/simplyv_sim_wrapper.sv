// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: Simulation wrapper of the embedded SoC, shared by every backend.
//              simplyv is built with VERIFICATION: the testbench drives the clocks,
//              the PLL lock, the core reset (in place of the VIO) and the AXI port
//              of sys_master (in place of JTAG2AXI). glbl is instantiated here, as
//              the single top of Verilator; the xsim flow defines VERILATOR too.

`include "simplyv_axi.svh"

import simplyv_pkg::*;

module simplyv_sim_wrapper (
    input  logic                         sys_clock_i,
    input  logic                         sys_reset_i,
    input  logic                         uart_rx_i,
    output logic                         uart_tx_o,
    input  logic [GPIO_IN_WIDTH  -1 : 0] gpio_in_i,
    output logic [GPIO_OUT_WIDTH -1 : 0] gpio_out_o,
    input  logic                         clk_10MHz_i,
    input  logic                         clk_20MHz_i,
    input  logic                         clk_50MHz_i,
    input  logic                         clk_100MHz_i,
    input  logic                         locked_i,
    input  logic                         vio_resetn_i,
    `DEFINE_AXI_SLAVE_PORTS(jtag, 32, MBUS_ADDR_WIDTH, MBUS_ID_WIDTH)
);

    simplyv simplyv_u ( .* );

`ifdef VERILATOR
    glbl glbl ();
`endif

endmodule : simplyv_sim_wrapper
