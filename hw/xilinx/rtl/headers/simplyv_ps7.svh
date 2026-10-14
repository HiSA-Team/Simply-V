// Author: Federica Sarnataro
// Description: Utility macros for the Zynq-7000 PS fixed I/O (DDR and FIXED_IO).
//              These pins are hard-wired to the PS and only need to be routed
//              from the PS wrapper (xlnx_ps_wrapper) up to the top level.

`ifndef SIMPLYV_PS7_SVH__
`define SIMPLYV_PS7_SVH__

// PS7 ports (Zynq-7020, 32-bit DDR3)
`define DEFINE_PS7_PORTS                     \
    inout  logic [14:0]  ps_ddr_addr,        \
    inout  logic [2:0]   ps_ddr_ba,          \
    inout  logic         ps_ddr_cas_n,       \
    inout  logic         ps_ddr_ck_n,        \
    inout  logic         ps_ddr_ck_p,        \
    inout  logic         ps_ddr_cke,         \
    inout  logic         ps_ddr_cs_n,        \
    inout  logic [3:0]   ps_ddr_dm,          \
    inout  logic [31:0]  ps_ddr_dq,          \
    inout  logic [3:0]   ps_ddr_dqs_n,       \
    inout  logic [3:0]   ps_ddr_dqs_p,       \
    inout  logic         ps_ddr_odt,         \
    inout  logic         ps_ddr_ras_n,       \
    inout  logic         ps_ddr_reset_n,     \
    inout  logic         ps_ddr_we_n,        \
    inout  logic         ps_fixed_io_ddr_vrn,  \
    inout  logic         ps_fixed_io_ddr_vrp,  \
    inout  logic [53:0]  ps_fixed_io_mio,      \
    inout  logic         ps_fixed_io_ps_clk,   \
    inout  logic         ps_fixed_io_ps_porb,  \
    inout  logic         ps_fixed_io_ps_srstb

// Connect PS7 ports with the same name
`define CONNECT_PS7_PORTS                           \
    .ps_ddr_addr         ( ps_ddr_addr         ),   \
    .ps_ddr_ba           ( ps_ddr_ba           ),   \
    .ps_ddr_cas_n        ( ps_ddr_cas_n        ),   \
    .ps_ddr_ck_n         ( ps_ddr_ck_n         ),   \
    .ps_ddr_ck_p         ( ps_ddr_ck_p         ),   \
    .ps_ddr_cke          ( ps_ddr_cke          ),   \
    .ps_ddr_cs_n         ( ps_ddr_cs_n         ),   \
    .ps_ddr_dm           ( ps_ddr_dm           ),   \
    .ps_ddr_dq           ( ps_ddr_dq           ),   \
    .ps_ddr_dqs_n        ( ps_ddr_dqs_n        ),   \
    .ps_ddr_dqs_p        ( ps_ddr_dqs_p        ),   \
    .ps_ddr_odt          ( ps_ddr_odt          ),   \
    .ps_ddr_ras_n        ( ps_ddr_ras_n        ),   \
    .ps_ddr_reset_n      ( ps_ddr_reset_n      ),   \
    .ps_ddr_we_n         ( ps_ddr_we_n         ),   \
    .ps_fixed_io_ddr_vrn ( ps_fixed_io_ddr_vrn ),   \
    .ps_fixed_io_ddr_vrp ( ps_fixed_io_ddr_vrp ),   \
    .ps_fixed_io_mio     ( ps_fixed_io_mio     ),   \
    .ps_fixed_io_ps_clk  ( ps_fixed_io_ps_clk  ),   \
    .ps_fixed_io_ps_porb ( ps_fixed_io_ps_porb ),   \
    .ps_fixed_io_ps_srstb( ps_fixed_io_ps_srstb )

`endif
