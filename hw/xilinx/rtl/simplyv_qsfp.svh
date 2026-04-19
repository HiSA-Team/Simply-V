// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description: Utility variables and macros for QSFP28 interface

`ifndef SIMPLYV_QSFP_SVH__
`define SIMPLYV_QSFP_SVH__

// QSFP Lanes
localparam unsigned QSFP_LANES = 4;

// QSFP Ports
// port admitted values: 0, 1 (on the Alveo U250)

`define DEFINE_QSFP_PORTS(port)                       \
    input  logic [QSFP_LANES-1:0] qsfp``port``_rxp_i, \
    input  logic [QSFP_LANES-1:0] qsfp``port``_rxn_i, \
    output logic [QSFP_LANES-1:0] qsfp``port``_txp_o, \
    output logic [QSFP_LANES-1:0] qsfp``port``_txn_o


`endif // SIMPLYV_QSFP_SVH