// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: Verilator model of the LUT1 primitive for the Xilinx IP netlists: 0/1 only

module LUT1 #(parameter [1:0] INIT = 0) (output O, input I0);
  assign O = INIT[{I0}];
endmodule
