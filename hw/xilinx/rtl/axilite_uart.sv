// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description: AXI4 Uart - This module encapsulates the AXI lite uart. The uart is selected based on the SOC_CONFIG.
//              EMBEDDED -> AXILITE UART
//              HPC      -> VIRTUAL UART


// Import packages
import uninasoc_pkg::*;

// Import headers
`include "uninasoc_axi.svh"


module axilite_uart # (
    parameter int unsigned    LOCAL_DATA_WIDTH  = 32,
    parameter int unsigned    LOCAL_ADDR_WIDTH  = 32,
    parameter int unsigned    LOCAL_ID_WIDTH    = 2
    ) (
    input logic clock_i,
    input logic reset_ni,

    // Interrupts
    output logic        int_core_o,
    output logic        int_xdma_o,
    input  logic [1:0]  int_ack_i,

    // AXI4 Slave interface
    `DEFINE_AXILITE_SLAVE_PORTS(s, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH),

    // EMBEDDED ONLY
    // RX and TX signas
    output logic        tx_o,
    input  logic        rx_i

);

    `ifdef HPC
        virtual_uart virtual_uart_u (
            .clock_i    ( clock_i                       ),
            .reset_ni   ( reset_ni                      ),
            .int_core_o ( int_core_o                    ),
            .int_xdma_o ( int_xdma_o                    ),
            .int_ack_i  ( 2'b00                         ),

            .s_axilite_awaddr   ( s_axilite_awaddr       ), // output wire [31 : 0] s_axilite_awaddr
            .s_axilite_awprot   ( s_axilite_awprot       ), // output wire [2 : 0] s_axilite_awprot
            .s_axilite_awvalid  ( s_axilite_awvalid      ), // output wire s_axilite_awvalid
            .s_axilite_awready  ( s_axilite_awready      ), // input wire s_axilite_awready
            .s_axilite_wdata    ( s_axilite_wdata        ), // output wire [31 : 0] s_axilite_wdata
            .s_axilite_wstrb    ( s_axilite_wstrb        ), // output wire [3 : 0] s_axilite_wstrb
            .s_axilite_wvalid   ( s_axilite_wvalid       ), // output wire s_axilite_wvalid
            .s_axilite_wready   ( s_axilite_wready       ), // input wire s_axilite_wready
            .s_axilite_bresp    ( s_axilite_bresp        ), // input wire [1 : 0] s_axilite_bresp
            .s_axilite_bvalid   ( s_axilite_bvalid       ), // input wire s_axilite_bvalid
            .s_axilite_bready   ( s_axilite_bready       ), // output wire s_axilite_bready
            .s_axilite_araddr   ( s_axilite_araddr       ), // output wire [31 : 0] s_axilite_araddr
            .s_axilite_arprot   ( s_axilite_arprot       ), // output wire [2 : 0] s_axilite_arprot
            .s_axilite_arvalid  ( s_axilite_arvalid      ), // output wire s_axilite_arvalid
            .s_axilite_arready  ( s_axilite_arready      ), // input wire s_axilite_arready
            .s_axilite_rdata    ( s_axilite_rdata        ), // input wire [31 : 0] s_axilite_rdata
            .s_axilite_rresp    ( s_axilite_rresp        ), // input wire [1 : 0] s_axilite_rresp
            .s_axilite_rvalid   ( s_axilite_rvalid       ), // input wire s_axilite_rvalid
            .s_axilite_rready   ( s_axilite_rready       )  // output wire s_axi_rready

        );

    `elsif EMBEDDED
        xlnx_axi_uartlite uart_u (
            .s_axi_aclk         ( clock_i                           ),      // input wire s_axi_aclk
            .s_axi_aresetn      ( reset_ni                          ),      // input wire s_axi_aresetn
            .interrupt          ( int_core_o                        ),      // output wire interrupt
            .s_axi_awaddr       ( s_axilite_awaddr                  ),      // input wire [3 : 0] s_axi_awaddr
            .s_axi_awvalid      ( s_axilite_awvalid                 ),      // input wire s_axi_awvalid
            .s_axi_awready      ( s_axilite_awready                 ),      // output wire s_axi_awready
            .s_axi_wdata        ( s_axilite_wdata                   ),      // input wire [31 : 0] s_axi_wdata
            .s_axi_wstrb        ( s_axilite_wstrb                   ),      // input wire [3 : 0] s_axi_wstrb
            .s_axi_wvalid       ( s_axilite_wvalid                  ),      // input wire s_axi_wvalid
            .s_axi_wready       ( s_axilite_wready                  ),      // output wire s_axi_wready
            .s_axi_bresp        ( s_axilite_bresp                   ),      // output wire [1 : 0] s_axi_bresp
            .s_axi_bvalid       ( s_axilite_bvalid                  ),      // output wire s_axi_bvalid
            .s_axi_bready       ( s_axilite_bready                  ),      // input wire s_axi_bready
            .s_axi_araddr       ( s_axilite_araddr                  ),      // input wire [3 : 0] s_axi_araddr
            .s_axi_arvalid      ( s_axilite_arvalid                 ),      // input wire s_axi_arvalid
            .s_axi_arready      ( s_axilite_arready                 ),      // output wire s_axi_arready
            .s_axi_rdata        ( s_axilite_rdata                   ),      // output wire [31 : 0] s_axi_rdata
            .s_axi_rresp        ( s_axilite_rresp                   ),      // output wire [1 : 0] s_axi_rresp
            .s_axi_rvalid       ( s_axilite_rvalid                  ),      // output wire s_axi_rvalid
            .s_axi_rready       ( s_axilite_rready                  ),      // input wire s_axi_rready
            .rx                 ( rx_i                              ),      // input wire rx
            .tx                 ( tx_o                              )       // output wire tx
        );

        assign int_xdma_o = '0;

    `endif

endmodule
