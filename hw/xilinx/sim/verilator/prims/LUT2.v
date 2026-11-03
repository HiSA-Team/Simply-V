// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: Verilator model of the LUT2 primitive for the Xilinx IP netlists: 0/1 only

module LUT2 #(parameter [3:0] INIT = 0) (output O, input I1, input I0);
  assign O = INIT[{I1,I0}];
endmodule
