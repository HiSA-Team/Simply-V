// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: Verilator model of the LUT6 primitive for the Xilinx IP netlists: 0/1 only

module LUT6 #(parameter [63:0] INIT = 0) (output O, input I5, input I4, input I3, input I2, input I1, input I0);
  assign O = INIT[{I5,I4,I3,I2,I1,I0}];
endmodule
