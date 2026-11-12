// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: Verilator model of the LUT3 primitive for the Xilinx IP netlists: 0/1 only

module LUT3 #(parameter [7:0] INIT = 0) (output O, input I2, input I1, input I0);
  assign O = INIT[{I2,I1,I0}];
endmodule
