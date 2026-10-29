// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: AXI4-Lite crossbar, NUM_SI slave ports to NUM_MI master ports.
//              Address decode on MI_BASE/MI_RANGE_BITS (one range per master port),
//              round-robin arbitration per master port, DECERR on unmapped addresses.
//              AXI-Lite has no IDs: the owner of each master port is recorded until
//              the response returns. AW and W are independent handshakes, so a slave
//              that holds AWREADY until WVALID cannot deadlock the crossbar.
// NOTE: one outstanding transaction per port and channel.

`include "simplyv_axi.svh"

module simplyv_axilite_xbar #(
    parameter int unsigned NUM_SI     = 1,
    parameter int unsigned NUM_MI     = 2,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned ADDR_WIDTH = 32,
    parameter logic [NUM_MI-1:0][ADDR_WIDTH-1:0] MI_BASE       = '0,
    parameter logic [NUM_MI-1:0][7:0]            MI_RANGE_BITS = '0
) (
    input  logic aclk,
    input  logic aresetn,

    `DEFINE_AXILITE_SLAVE_PORTS_ARRAY(s, NUM_SI, DATA_WIDTH, ADDR_WIDTH),
    `DEFINE_AXILITE_MASTER_PORTS_ARRAY(m, NUM_MI, DATA_WIDTH, ADDR_WIDTH)
);

    localparam int unsigned SI_W     = (NUM_SI > 1) ? $clog2(NUM_SI) : 1;
    localparam int unsigned NUM_MI_E = NUM_MI + 1;                 // + error slave
    localparam int unsigned MI_W     = $clog2(NUM_MI_E);
    localparam logic [1:0] DECERR    = 2'b11;
    // Magic value returned on the read data of an unmapped address
    localparam logic [DATA_WIDTH-1:0] ERR_RDATA = {(DATA_WIDTH/32){32'h5BADBEEF}};

    function automatic logic [MI_W-1:0] decode(input logic [ADDR_WIDTH-1:0] addr);
        decode = MI_W'(NUM_MI);
        for (int j = 0; j < NUM_MI; j++)
            if ((addr >> MI_RANGE_BITS[j]) == (MI_BASE[j] >> MI_RANGE_BITS[j])) decode = MI_W'(j);
    endfunction

    function automatic logic [NUM_SI-1:0] rr_pick(input logic [NUM_SI-1:0] req, input logic [SI_W-1:0] ptr);
        rr_pick = '0;
        for (int k = 0; k < NUM_SI; k++) begin
            int i = (int'(ptr) + k >= NUM_SI) ? int'(ptr) + k - NUM_SI : int'(ptr) + k;
            if (req[i] && rr_pick == '0) rr_pick[i] = 1'b1;
        end
    endfunction

    function automatic logic [SI_W-1:0] onehot_idx(input logic [NUM_SI-1:0] oh);
        onehot_idx = '0;
        for (int i = 0; i < NUM_SI; i++) if (oh[i]) onehot_idx = SI_W'(i);
    endfunction

    logic [NUM_SI-1:0]               si_wr_busy, si_rd_busy;
    logic [NUM_SI-1:0][MI_W-1:0]     aw_dec, ar_dec;
    logic [NUM_MI_E-1:0][NUM_SI-1:0] aw_req, aw_gnt, ar_req, ar_gnt;
    logic [NUM_MI_E-1:0][SI_W-1:0]   aw_rr, ar_rr, aw_idx, ar_idx;

    // Write side: owner latched on the first grant and held until the B response;
    // aw_done/w_done track the two handshakes separately
    logic [NUM_MI_E-1:0]             wr_busy, aw_done, w_done;
    logic [NUM_MI_E-1:0][SI_W-1:0]   wr_owner;

    // Read side: grant held per master port while valid and not yet
    // accepted (address stability); one outstanding read per port.
    logic [NUM_MI_E-1:0]             ar_lock;
    logic [NUM_MI_E-1:0][SI_W-1:0]   ar_lock_idx;
    logic [NUM_MI_E-1:0]             rd_st;
    logic [NUM_MI_E-1:0][SI_W-1:0]   rd_owner;

    // Internal master-side buses; index NUM_MI is the error slave
    `DECLARE_AXILITE_BUS_ARRAY(mi, NUM_MI_E, DATA_WIDTH, ADDR_WIDTH)
    `DECLARE_AXILITE_BUS(err, DATA_WIDTH, ADDR_WIDTH)
    logic [NUM_MI_E-1:0][SI_W-1:0] cur_owner;
    logic [NUM_MI_E-1:0] aw_v, w_v, resp_ready;

    always_comb begin
        for (int i = 0; i < NUM_SI; i++) begin
            aw_dec[i] = decode(s_axilite_awaddr[i]);
            ar_dec[i] = decode(s_axilite_araddr[i]);
        end
        aw_req = '0; ar_req = '0;
        for (int i = 0; i < NUM_SI; i++) begin
            if (s_axilite_awvalid[i] && !si_wr_busy[i] && !wr_busy[aw_dec[i]]) aw_req[aw_dec[i]][i] = 1'b1;
            if (s_axilite_arvalid[i] && !si_rd_busy[i] && !rd_st[ar_dec[i]])   ar_req[ar_dec[i]][i] = 1'b1;
        end
        for (int j = 0; j < NUM_MI_E; j++) begin
            aw_gnt[j] = rr_pick(aw_req[j], aw_rr[j]);
            aw_idx[j] = onehot_idx(aw_gnt[j]);
            if (ar_lock[j]) begin
                automatic int li = int'(ar_lock_idx[j]);
                ar_gnt[j]     = '0;
                ar_gnt[j][li] = 1'b1;
                ar_idx[j]     = ar_lock_idx[j];
            end else begin
                ar_gnt[j] = rr_pick(ar_req[j], ar_rr[j]); ar_idx[j] = onehot_idx(ar_gnt[j]);
            end
            cur_owner[j]  = wr_busy[j] ? wr_owner[j] : aw_idx[j];
            aw_v[j]       = (!wr_busy[j] && |aw_gnt[j]) || (wr_busy[j] && !aw_done[j]);
            w_v[j]        = (!wr_busy[j] && |aw_gnt[j]) || (wr_busy[j] && !w_done[j]);
            resp_ready[j] = wr_busy[j] && aw_done[j] && w_done[j];
        end
    end

    // Per master port: payload of the current owner, handshakes and B/R back to it
    always_comb begin
        s_axilite_awready = '0; s_axilite_arready = '0; s_axilite_wready = '0;
        s_axilite_bvalid = '0; s_axilite_bresp = '0; s_axilite_rvalid = '0; s_axilite_rresp = '0; s_axilite_rdata = '0;
        mi_axilite_bready = '0; mi_axilite_rready = '0;
        for (int j = 0; j < NUM_MI_E; j++) begin
            automatic int ai = int'(cur_owner[j]);
            automatic int ri = int'(ar_idx[j]);
            automatic int wo = int'(wr_owner[j]);
            automatic int ro = int'(rd_owner[j]);
            mi_axilite_awvalid[j] = aw_v[j];
            mi_axilite_awaddr[j]  = s_axilite_awaddr[ai];
            mi_axilite_awprot[j]  = s_axilite_awprot[ai];
            mi_axilite_arvalid[j] = |ar_gnt[j];
            mi_axilite_araddr[j]  = s_axilite_araddr[ri];
            mi_axilite_arprot[j]  = s_axilite_arprot[ri];
            mi_axilite_wvalid[j]  = w_v[j] && s_axilite_wvalid[ai];
            mi_axilite_wdata[j]   = s_axilite_wdata[ai];
            mi_axilite_wstrb[j]   = s_axilite_wstrb[ai];
            if (aw_v[j])     s_axilite_awready[ai] = mi_axilite_awready[j];
            if (|ar_gnt[j])  s_axilite_arready[ri] = mi_axilite_arready[j];
            if (w_v[j])      s_axilite_wready[ai]  = mi_axilite_wready[j];
            if (resp_ready[j] && mi_axilite_bvalid[j]) begin s_axilite_bvalid[wo] = 1'b1; s_axilite_bresp[wo] = mi_axilite_bresp[j]; mi_axilite_bready[j] = s_axilite_bready[wo]; end
            if (rd_st[j] && mi_axilite_rvalid[j]) begin s_axilite_rvalid[ro] = 1'b1; s_axilite_rresp[ro] = mi_axilite_rresp[j]; s_axilite_rdata[ro] = mi_axilite_rdata[j]; mi_axilite_rready[j] = s_axilite_rready[ro]; end
        end
    end

    // Error slave: accepts every request, answers DECERR
    assign err_axilite_awready = 1'b1;
    assign err_axilite_wready  = 1'b1;
    assign err_axilite_arready = 1'b1;
    assign err_axilite_bvalid  = resp_ready[NUM_MI];
    assign err_axilite_bresp   = DECERR;
    assign err_axilite_rvalid  = rd_st[NUM_MI];
    assign err_axilite_rresp   = DECERR;
    assign err_axilite_rdata   = ERR_RDATA;

    `CONCAT_AXILITE_SLAVES_ARRAY2(mi, err, m)

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            si_wr_busy <= '0; si_rd_busy <= '0; rd_st <= '0; aw_rr <= '0; ar_rr <= '0; rd_owner <= '0;
            ar_lock <= '0;
            wr_busy <= '0; wr_owner <= '0; aw_done <= '0; w_done <= '0;
        end else begin
            for (int i = 0; i < NUM_SI; i++) begin
                if (s_axilite_awvalid[i] && s_axilite_awready[i]) si_wr_busy[i] <= 1'b1;
                if (s_axilite_bvalid[i] && s_axilite_bready[i])   si_wr_busy[i] <= 1'b0;
                if (s_axilite_arvalid[i] && s_axilite_arready[i]) si_rd_busy[i] <= 1'b1;
                if (s_axilite_rvalid[i] && s_axilite_rready[i])   si_rd_busy[i] <= 1'b0;
            end
            for (int j = 0; j < NUM_MI_E; j++) begin
                automatic logic aw_fire = mi_axilite_awvalid[j] && mi_axilite_awready[j];
                automatic logic w_fire  = mi_axilite_wvalid[j]  && mi_axilite_wready[j];
                if (!wr_busy[j]) begin
                    if (|aw_gnt[j]) begin
                        wr_busy[j]  <= 1'b1;
                        wr_owner[j] <= aw_idx[j];
                        aw_done[j]  <= aw_fire;
                        w_done[j]   <= w_fire;
                        aw_rr[j]    <= (int'(aw_idx[j]) + 1 >= NUM_SI) ? '0 : aw_idx[j] + 1'b1;
                    end
                end else begin
                    if (aw_fire) aw_done[j] <= 1'b1;
                    if (w_fire)  w_done[j]  <= 1'b1;
                    if (resp_ready[j] && mi_axilite_bvalid[j] && mi_axilite_bready[j]) begin
                        wr_busy[j] <= 1'b0; aw_done[j] <= 1'b0; w_done[j] <= 1'b0;
                    end
                end
                if (mi_axilite_arvalid[j] && mi_axilite_arready[j]) begin
                    rd_st[j] <= 1'b1; rd_owner[j] <= ar_idx[j];
                    ar_rr[j] <= (int'(ar_idx[j]) + 1 >= NUM_SI) ? '0 : ar_idx[j] + 1'b1;
                end
                if (rd_st[j] && mi_axilite_rvalid[j] && mi_axilite_rready[j]) rd_st[j] <= 1'b0;
                if (mi_axilite_arvalid[j] && !mi_axilite_arready[j]) begin ar_lock[j] <= 1'b1; ar_lock_idx[j] <= ar_idx[j]; end
                else ar_lock[j] <= 1'b0;
            end
        end
    end

endmodule
