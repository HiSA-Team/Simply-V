// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: Verilator model of the LUT5 primitive for the Xilinx IP netlists: 0/1 only

module LUT5 #(parameter [31:0] INIT = 0) (output O, input I4, input I3, input I2, input I1, input I0);
  assign O = INIT[{I4,I3,I2,I1,I0}];
endmodule
