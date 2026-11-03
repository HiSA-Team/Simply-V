// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: Verilator model of the FDRE primitive for the Xilinx IP netlists: 0/1 only,
//              IS_*_INVERTED not supported (unset in the netlists)

module FDRE #(parameter [0:0] INIT = 1'b0, IS_C_INVERTED = 0, IS_D_INVERTED = 0, IS_R_INVERTED = 0) (output reg Q = INIT, input C, CE, D, R);
  initial if (IS_C_INVERTED | IS_D_INVERTED | IS_R_INVERTED) $fatal(1, "FDRE: IS_*_INVERTED not supported");
  always @(posedge C) if (R) Q <= 1'b0; else if (CE) Q <= D;
endmodule
