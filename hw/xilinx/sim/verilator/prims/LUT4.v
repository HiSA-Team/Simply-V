// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: Verilator model of the LUT4 primitive for the Xilinx IP netlists: 0/1 only

module LUT4 #(parameter [15:0] INIT = 0) (output O, input I3, input I2, input I1, input I0);
  assign O = INIT[{I3,I2,I1,I0}];
endmodule
