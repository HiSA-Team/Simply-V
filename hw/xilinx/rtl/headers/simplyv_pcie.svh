// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description: Utility variables and macros for PCIe interface

`ifndef SIMPLYV_PCIE_SVH__
`define SIMPLYV_PCIE_SVH__

//////////////////
// PCIe defines //
//////////////////
localparam int unsigned NUM_PCIE_LANES = 8;

// PCIe define ports
`define DEFINE_PCIE_PORTS()                          \
    input  logic [NUM_PCIE_LANES-1:0] pci_exp_rxn_i, \
    input  logic [NUM_PCIE_LANES-1:0] pci_exp_rxp_i, \
    output logic [NUM_PCIE_LANES-1:0] pci_exp_txn_o, \
    output logic [NUM_PCIE_LANES-1:0] pci_exp_txp_o

`endif