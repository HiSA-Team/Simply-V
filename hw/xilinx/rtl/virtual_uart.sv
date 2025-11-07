// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description: Virtual Uart - This module simulates the physical uart connected to XDMA through AXI lite


// Import packages
import uninasoc_pkg::*;

// Import headers
`include "uninasoc_axi.svh"


module virtual_uart # (
    parameter int unsigned    LOCAL_DATA_WIDTH  = 32,
    parameter int unsigned    LOCAL_ADDR_WIDTH  = 32,
    parameter int unsigned    LOCAL_ID_WIDTH    = 32
) (
    input logic clock_i,
    input logic reset_ni,

    // Interrupts
    // 0 - to the Core
    // 1 - to the XDMA
    output logic int_core_o,
    output logic int_xdma_o,
    input  logic [1:0] int_ack_i,

    // AXILITE Slave interface
    `DEFINE_AXILITE_SLAVE_PORTS(s, LOCAL_DATA_WIDTH, LOCAL_ADDR_WIDTH, LOCAL_ID_WIDTH)
);


    // Uart CSR - for more details see PG142
    // 0 - 00h - RX register
    // 1 - 04h - TX register
    // 2 - 08h - Status register
    // 3 - 0Ch - Control register
    // 4 - 10h - ACK from the host interrupt
    localparam RX_REG           = 0;
    localparam TX_REG           = 1;
    localparam STATUS_REG       = 2;
    localparam CONTROL_REG      = 3;
    localparam HOST_INT_ACK_REG = 4;

    // Control/status register bit position
    localparam CTRL_RST_TX_BIT  = 0;     // Control - Reset TX register
    localparam CTRL_RST_RX_BIT  = 0;     // Control - Reset RX register
    localparam CTRL_STS_INT_BIT = 4;     // Control and status - Interrupt enable
    localparam STS_RX_VALID_BIT = 0;     // Status  - RX register valid
    localparam STS_RX_FULL_BIT  = 1;     // Status  - RX register full
    localparam STS_TX_EMPTY_BIT = 2;     // Status  - TX register empty
    localparam STS_TX_FULL_BIT  = 3;     // Status  - TX register full

    logic [LOCAL_DATA_WIDTH-1:0] uart_csr [0:4];


    /* AXILITE Write logic */
    always_ff @( posedge clock_i or negedge reset_ni ) begin
        if ( !reset_ni ) begin
            s_axilite_awready <= 1'b0;
        end
        else begin
            s_axilite_awready <= (s_axilite_awvalid && !s_axilite_awready);
        end
    end

    always_ff @( posedge clock_i or negedge reset_ni ) begin
        if ( !reset_ni ) begin
            s_axilite_wready <= 1'b0;
            s_axilite_bvalid <= 1'b0;
            s_axilite_bresp  <= 2'b00;
        end
        else begin
            if ( s_axilite_wvalid && s_axilite_wready && s_axilite_awvalid && s_axilite_awready ) begin
                s_axilite_bvalid <= 1'b1;
                s_axilite_bresp  <= 2'b00;

            end
            if ( s_axilite_bvalid && s_axilite_bready ) begin
                s_axilite_bvalid <= 1'b0;
            end

            s_axilite_wready <= (s_axilite_wvalid && s_axilite_awvalid && !s_axilite_awready);
        end
    end


    /* AXILITE Read logic */
    always_ff @( posedge clock_i or negedge reset_ni ) begin
        if ( !reset_ni ) begin
            s_axilite_arready <= 1'b0;
            s_axilite_rvalid  <= 1'b0;
            s_axilite_rdata   <= 0;
            s_axilite_rresp   <= 2'b00;
        end else begin

            if (s_axilite_arvalid && !s_axilite_arready) begin
                s_axilite_arready <= 1'b1;
            end else begin
                s_axilite_arready <= 1'b0;
            end

            if (s_axilite_arvalid && s_axilite_arready) begin
                s_axilite_rdata <= uart_csr[s_axilite_araddr[4:2]];
                s_axilite_rvalid <= 1'b1;
                s_axilite_rresp  <= 2'b00;
            end
            if (s_axilite_rvalid && s_axilite_rready) begin
                s_axilite_rvalid <= 1'b0;
            end
        end
    end

    // Control/Status register logic
    always_ff @( posedge clock_i or negedge reset_ni ) begin
        if ( !reset_ni ) begin
            foreach(uart_csr[i]) uart_csr[i] <= 0;
        end
        else begin
            if ( s_axilite_wvalid && s_axilite_wready && s_axilite_awvalid && s_axilite_awready ) begin
                // If there is a write on the control register
                if ( s_axilite_awaddr[4:2] == CONTROL_REG /*&& s_axilite_wstrb[0]*/ ) begin

                    // RST TX register
                    if (s_axilite_wdata[CTRL_RST_TX_BIT]) begin
                        uart_csr[TX_REG] <= 0;
                        // TX register empty
                        uart_csr[STATUS_REG][STS_TX_EMPTY_BIT] <= 1'b1;
                        // TX register full
                        uart_csr[STATUS_REG][STS_TX_FULL_BIT] <= 1'b0;
                    end

                    // RST RX register
                    if (s_axilite_wdata[CTRL_RST_RX_BIT]) begin
                        uart_csr[RX_REG] <= 0;
                        // RX register valid
                        uart_csr[STATUS_REG][STS_RX_VALID_BIT] <= 1'b0;
                        // RX register full
                        uart_csr[STATUS_REG][STS_RX_FULL_BIT] <= 1'b0;
                    end

                    // Propagate the interrupt enable/disable on the status register
                    uart_csr[STATUS_REG][CTRL_STS_INT_BIT] <= s_axilite_wdata[CTRL_STS_INT_BIT];
                end

                // There is a write on the RX register
                else if ( s_axilite_awaddr[4:2] == RX_REG /*&& s_axilite_wstrb[0]*/ ) begin
                    // save data
                    uart_csr[RX_REG][7:0] <= s_axilite_wdata[7:0];
                    // RX register valid
                    uart_csr[STATUS_REG][STS_RX_VALID_BIT] <= 1'b1;
                    // RX register full
                    uart_csr[STATUS_REG][STS_RX_FULL_BIT] <= 1'b1;
                end

                // There is a write on the TX register
                else if ( s_axilite_awaddr[4:2] == TX_REG /*&& s_axilite_wstrb[0]*/ ) begin
                    // save data
                    uart_csr[TX_REG][7:0] <= s_axilite_wdata[7:0];
                    // TX register empty
                    uart_csr[STATUS_REG][STS_TX_EMPTY_BIT] <= 1'b0;
                    // TX register full
                    uart_csr[STATUS_REG][STS_TX_FULL_BIT] <= 1'b1;
                end

            end

            if ( s_axilite_arvalid && s_axilite_arready ) begin

                // There is a read on the RX register
                if ( s_axilite_araddr[4:2] == RX_REG ) begin
                    // RX register valid
                    uart_csr[STATUS_REG][STS_RX_VALID_BIT] <= 1'b0;
                    // RX register full
                    uart_csr[STATUS_REG][STS_RX_FULL_BIT] <= 1'b0;
                end

                // There is a read on the TX register
                else if ( s_axilite_araddr[4:2] == TX_REG ) begin
                    // TX register empty
                    uart_csr[STATUS_REG][STS_TX_EMPTY_BIT] <= 1'b1;
                    // TX register full
                    uart_csr[STATUS_REG][STS_TX_FULL_BIT] <= 1'b0;
                end
            end


        end
    end

    // Interrupts logic
    // THIS IS A STUB - TO DO
    always_ff @( posedge clock_i or negedge reset_ni ) begin
        if ( !reset_ni ) begin
            int_core_o <= '0;
            int_xdma_o <= '0;
        end
        else begin
            if ( s_axilite_wvalid && s_axilite_wready && s_axilite_awvalid && s_axilite_awready ) begin

                // There is a write on TX reg, need to interrupt the XDMA
                if ( s_axilite_awaddr[4:2] == TX_REG /*&& s_axilite_wstrb[0]*/ ) begin
                    int_xdma_o <= 1'b1;
                end

                // There is a write on HOST ACK register reset the interrupt to the XDMA
                else if ( s_axilite_awaddr[4:2] == HOST_INT_ACK_REG /*&& s_axilite_wstrb[0]*/ ) begin
                    int_xdma_o <= 1'b0;
                end


            end
        end
    end

endmodule