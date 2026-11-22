// Description: Nexys A7 x16 DDR2 memory interface.

`ifndef SIMPLYV_DDR2_SVH__
`define SIMPLYV_DDR2_SVH__

`define DEFINE_DDR2_PORTS \
    inout logic [15:0]   ddr2_dq, \
    inout logic [1:0]    ddr2_dqs_n, \
    inout logic [1:0]    ddr2_dqs_p, \
    output logic [12:0]  ddr2_addr, \
    output logic [2:0]   ddr2_ba, \
    output logic         ddr2_ras_n, \
    output logic         ddr2_cas_n, \
    output logic         ddr2_we_n, \
    output logic [0:0]   ddr2_ck_p, \
    output logic [0:0]   ddr2_ck_n, \
    output logic [0:0]   ddr2_cke, \
    output logic [0:0]   ddr2_cs_n, \
    output logic [1:0]   ddr2_dm, \
    output logic [0:0]   ddr2_odt

`endif
