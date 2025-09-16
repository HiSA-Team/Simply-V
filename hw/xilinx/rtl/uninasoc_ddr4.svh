// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description: Utility variables and macros for DDR4 interface

`ifndef UNINASOC_DDR4_SVH__
`define UNINASOC_DDR4_SVH__


// DDR4 Ports
// ch admitted values: 0, 1, 2, 3

`define DEFINE_DDR4_PORTS(channel)                  \
    output logic [16:0]  c``channel``_ddr4_adr,     \
    output logic [1:0]   c``channel``_ddr4_ba,      \
    output logic [1:0]   c``channel``_ddr4_bg,      \
    output logic [0:0]   c``channel``_ddr4_ck_t,    \
    output logic [0:0]   c``channel``_ddr4_ck_c,    \
    output logic [0:0]   c``channel``_ddr4_cke,     \
    output logic [0:0]   c``channel``_ddr4_cs_n,    \
    output logic         c``channel``_ddr4_act_n,   \
    output logic [0:0]   c``channel``_ddr4_odt,     \
    output logic         c``channel``_ddr4_parity,  \
    output logic         c``channel``_ddr4_reset_n, \
    inout  logic [71:0]  c``channel``_ddr4_dq,      \
    inout  logic [17:0]  c``channel``_ddr4_dqs_t,   \
    inout  logic [17:0]  c``channel``_ddr4_dqs_c



`endif