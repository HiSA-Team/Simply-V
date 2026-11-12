// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: AXI4 error slave. Terminates the transactions the crossbar cannot
//              decode: the write burst is consumed and answered with DECERR, a
//              read burst of the requested length is answered with DECERR and
//              ERR_RDATA. One outstanding transaction per channel.

`include "simplyv_axi.svh"

module simplyv_axi_err_slv #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned ID_WIDTH   = 4
) (
    input  logic aclk,
    input  logic aresetn,

    `DEFINE_AXI_SLAVE_PORTS(s, DATA_WIDTH, ADDR_WIDTH, ID_WIDTH)
);

    localparam logic [1:0] DECERR = 2'b11;
    // Magic value returned on the read data of an unmapped address
    localparam logic [DATA_WIDTH-1:0] ERR_RDATA = {(DATA_WIDTH/32){32'h5BADBEEF}};

    // Write: accept AW, drain W up to WLAST, answer B
    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} wstate_t;
    wstate_t wstate;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            wstate    <= W_IDLE;
            s_axi_bid <= '0;
        end else begin
            case (wstate)
                W_IDLE: if (s_axi_awvalid) begin
                    s_axi_bid <= s_axi_awid;
                    wstate    <= W_DATA;
                end
                W_DATA: if (s_axi_wvalid && s_axi_wlast) wstate <= W_RESP;
                W_RESP: if (s_axi_bready) wstate <= W_IDLE;
                default: wstate <= W_IDLE;
            endcase
        end
    end

    assign s_axi_awready = (wstate == W_IDLE);
    assign s_axi_wready  = (wstate == W_DATA);
    assign s_axi_bvalid  = (wstate == W_RESP);
    assign s_axi_bresp   = DECERR;

    // Read: accept AR, answer ARLEN+1 beats
    typedef enum logic {R_IDLE, R_DATA} rstate_t;
    rstate_t    rstate;
    logic [7:0] rcnt;

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            rstate    <= R_IDLE;
            rcnt      <= '0;
            s_axi_rid <= '0;
        end else begin
            case (rstate)
                R_IDLE: if (s_axi_arvalid) begin
                    s_axi_rid <= s_axi_arid;
                    rcnt      <= s_axi_arlen;
                    rstate    <= R_DATA;
                end
                R_DATA: if (s_axi_rready) begin
                    rcnt <= rcnt - 8'd1;
                    if (rcnt == 8'd0) rstate <= R_IDLE;
                end
                default: rstate <= R_IDLE;
            endcase
        end
    end

    assign s_axi_arready = (rstate == R_IDLE);
    assign s_axi_rvalid  = (rstate == R_DATA);
    assign s_axi_rlast   = (rcnt == 8'd0);
    assign s_axi_rdata   = ERR_RDATA;
    assign s_axi_rresp   = DECERR;

endmodule
