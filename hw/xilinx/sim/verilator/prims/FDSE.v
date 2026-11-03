// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: Verilator model of the FDSE primitive for the Xilinx IP netlists: 0/1 only,
//              IS_*_INVERTED not supported (unset in the netlists)

module FDSE #(parameter [0:0] INIT = 1'b1, IS_C_INVERTED = 0, IS_D_INVERTED = 0, IS_S_INVERTED = 0) (output reg Q = INIT, input C, CE, D, S);
  initial if (IS_C_INVERTED | IS_D_INVERTED | IS_S_INVERTED) $fatal(1, "FDSE: IS_*_INVERTED not supported");
  always @(posedge C) if (S) Q <= 1'b1; else if (CE) Q <= D;
endmodule
