// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: AXI4 crossbar, NUM_SI slave ports to NUM_MI master ports, same port
//              names as the xlnx_*_crossbar IP. Address decode on MI_BASE/MI_RANGE_BITS
//              (one range per master port), round-robin arbitration per master port,
//              DECERR on unmapped addresses.
//              The slave-port index travels in the low $clog2(NUM_SI) bits of the ID
//              on the master side, thread bits above it, and routes B/R back; the
//              original ID is restored on the way back.
// NOTE: one outstanding transaction per slave port and channel.

`include "simplyv_axi.svh"

module simplyv_axi_xbar #(
    parameter int unsigned NUM_SI     = 2,
    parameter int unsigned NUM_MI     = 2,
    parameter int unsigned DATA_WIDTH = 32,
    parameter int unsigned ADDR_WIDTH = 32,
    parameter int unsigned ID_WIDTH   = 4,
    parameter logic [NUM_MI-1:0][ADDR_WIDTH-1:0] MI_BASE       = '0,
    parameter logic [NUM_MI-1:0][7:0]            MI_RANGE_BITS = '0
) (
    input  logic aclk,
    input  logic aresetn,

    `DEFINE_AXI_SLAVE_PORTS_ARRAY(s, NUM_SI, DATA_WIDTH, ADDR_WIDTH, ID_WIDTH),
    `DEFINE_AXI_MASTER_PORTS_ARRAY(m, NUM_MI, DATA_WIDTH, ADDR_WIDTH, ID_WIDTH)
);

    // ID layout: {thread bits, slave-port index}; index in the low bits
    localparam int unsigned SI_W     = (NUM_SI > 1) ? $clog2(NUM_SI) : 1;
    localparam int unsigned TH_W     = ID_WIDTH - SI_W;
    localparam int unsigned NUM_MI_E = NUM_MI + 1;            // + error slave
    localparam int unsigned MI_W     = $clog2(NUM_MI_E);

    if (ID_WIDTH <= SI_W) $error("ID_WIDTH (%0d) must exceed the slave-port index width (%0d)", ID_WIDTH, SI_W);

    // Internal master-side buses; index NUM_MI is the error slave
    `DECLARE_AXI_BUS_ARRAY(mi, NUM_MI_E, DATA_WIDTH, ADDR_WIDTH, ID_WIDTH)
    `DECLARE_AXI_BUS(err, DATA_WIDTH, ADDR_WIDTH, ID_WIDTH)

    /////////////
    // Decode  //
    /////////////

    function automatic logic [MI_W-1:0] decode(input logic [ADDR_WIDTH-1:0] addr);
        decode = MI_W'(NUM_MI);
        for (int j = 0; j < NUM_MI; j++)
            if ((addr >> MI_RANGE_BITS[j]) == (MI_BASE[j] >> MI_RANGE_BITS[j])) decode = MI_W'(j);
    endfunction

    // Round-robin pick: first requester at or after ptr
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

    function automatic logic [SI_W-1:0] next_ptr(input logic [SI_W-1:0] idx);
        next_ptr = (int'(idx) + 1 >= NUM_SI) ? '0 : idx + 1'b1;
    endfunction

    //////////////////////
    // Per-port state   //
    //////////////////////

    logic [NUM_SI-1:0]                  wr_busy, rd_busy;
    logic [NUM_SI-1:0][ID_WIDTH-1:0]    wr_id, rd_id;          // ID to restore on B/R
    logic [NUM_SI-1:0][MI_W-1:0]        aw_dec, ar_dec;
    logic [NUM_MI_E-1:0][NUM_SI-1:0]    aw_req, aw_gnt, ar_req, ar_gnt;
    logic [NUM_MI_E-1:0][SI_W-1:0]      aw_rr, ar_rr, aw_gnt_idx, ar_gnt_idx;

    // Grant held per master port while valid and not yet accepted, so the
    // payload on mi_axi_aw*/mi_axi_ar* cannot switch requester mid-stall (AXI address
    // stability). Independent for AW and AR.
    logic [NUM_MI_E-1:0]                aw_lock, ar_lock;
    logic [NUM_MI_E-1:0][SI_W-1:0]      aw_lock_idx, ar_lock_idx;

    // W-channel order per master port: slave-port indices in AW-accept order.
    // While the queue is empty, W may flow against the pending, not-yet-accepted
    // grant (W must not wait on AWREADY); w_done_pending then blocks further W
    // until that AW is accepted and skips its enqueue.
    logic [NUM_MI_E-1:0][NUM_SI-1:0][SI_W-1:0] wq;
    logic [NUM_MI_E-1:0][SI_W:0]               wq_cnt;
    logic [NUM_MI_E-1:0]                       w_done_pending;

    always_comb begin
        for (int i = 0; i < NUM_SI; i++) begin
            aw_dec[i] = decode(s_axi_awaddr[i]);
            ar_dec[i] = decode(s_axi_araddr[i]);
        end
        aw_req = '0;
        ar_req = '0;
        for (int i = 0; i < NUM_SI; i++) begin
            if (s_axi_awvalid[i] && !wr_busy[i]) aw_req[aw_dec[i]][i] = 1'b1;
            if (s_axi_arvalid[i] && !rd_busy[i]) ar_req[ar_dec[i]][i] = 1'b1;
        end
        for (int j = 0; j < NUM_MI_E; j++) begin
            if (aw_lock[j]) begin
                automatic int li = int'(aw_lock_idx[j]);
                aw_gnt[j]      = '0;
                aw_gnt[j][li]  = 1'b1;
                aw_gnt_idx[j]  = aw_lock_idx[j];
            end else begin
                aw_gnt[j]     = rr_pick(aw_req[j], aw_rr[j]);
                aw_gnt_idx[j] = onehot_idx(aw_gnt[j]);
            end
            if (ar_lock[j]) begin
                automatic int li = int'(ar_lock_idx[j]);
                ar_gnt[j]      = '0;
                ar_gnt[j][li]  = 1'b1;
                ar_gnt_idx[j]  = ar_lock_idx[j];
            end else begin
                ar_gnt[j]     = rr_pick(ar_req[j], ar_rr[j]);
                ar_gnt_idx[j] = onehot_idx(ar_gnt[j]);
            end
        end
    end

    ////////////////
    // AW and AR  //
    ////////////////

    always_comb begin
        for (int j = 0; j < NUM_MI_E; j++) begin
            automatic int i = int'(aw_gnt_idx[j]);
            mi_axi_awvalid[j] = |aw_gnt[j];
            mi_axi_awid[j]    = {s_axi_awid[i][TH_W-1:0], SI_W'(i)};
            mi_axi_awaddr[j]  = s_axi_awaddr[i];
            mi_axi_awlen[j]   = s_axi_awlen[i];
            mi_axi_awsize[j]  = s_axi_awsize[i];
            mi_axi_awburst[j] = s_axi_awburst[i];
            mi_axi_awlock[j]  = s_axi_awlock[i];
            mi_axi_awcache[j] = s_axi_awcache[i];
            mi_axi_awprot[j]  = s_axi_awprot[i];
            mi_axi_awqos[j]   = s_axi_awqos[i];
        end
        for (int j = 0; j < NUM_MI_E; j++) begin
            automatic int i = int'(ar_gnt_idx[j]);
            mi_axi_arvalid[j] = |ar_gnt[j];
            mi_axi_arid[j]    = {s_axi_arid[i][TH_W-1:0], SI_W'(i)};
            mi_axi_araddr[j]  = s_axi_araddr[i];
            mi_axi_arlen[j]   = s_axi_arlen[i];
            mi_axi_arsize[j]  = s_axi_arsize[i];
            mi_axi_arburst[j] = s_axi_arburst[i];
            mi_axi_arlock[j]  = s_axi_arlock[i];
            mi_axi_arcache[j] = s_axi_arcache[i];
            mi_axi_arprot[j]  = s_axi_arprot[i];
            mi_axi_arqos[j]   = s_axi_arqos[i];
        end
        for (int i = 0; i < NUM_SI; i++) begin
            s_axi_awready[i] = aw_gnt[aw_dec[i]][i] & mi_axi_awready[aw_dec[i]];
            s_axi_arready[i] = ar_gnt[ar_dec[i]][i] & mi_axi_arready[ar_dec[i]];
        end
    end

    ///////////
    // W     //
    ///////////

    always_comb begin
        s_axi_wready = '0;
        for (int j = 0; j < NUM_MI_E; j++) begin
            automatic int h = (wq_cnt[j] != '0) ? int'(wq[j][0]) : int'(aw_gnt_idx[j]);
            automatic logic w_active = (wq_cnt[j] != '0) | (mi_axi_awvalid[j] & ~w_done_pending[j]);
            mi_axi_wvalid[j] = w_active & s_axi_wvalid[h];
            mi_axi_wdata[j]  = s_axi_wdata[h];
            mi_axi_wstrb[j]  = s_axi_wstrb[h];
            mi_axi_wlast[j]  = s_axi_wlast[h];
            if (w_active) s_axi_wready[h] = mi_axi_wready[j];
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            wq_cnt         <= '0;
            wq             <= '0;
            w_done_pending <= '0;
        end else begin
            for (int j = 0; j < NUM_MI_E; j++) begin : wq_upd
                logic [SI_W:0] cnt;
                logic          wlast_fire, aw_fire;
                cnt        = wq_cnt[j];
                wlast_fire = mi_axi_wvalid[j] && mi_axi_wready[j] && mi_axi_wlast[j];
                aw_fire    = mi_axi_awvalid[j] && mi_axi_awready[j];
                if (cnt != '0) begin
                    if (wlast_fire) begin
                        for (int k = 0; k + 1 < NUM_SI; k++) wq[j][k] <= wq[j][k+1];
                        cnt = cnt - 1'b1;
                    end
                    if (aw_fire) begin
                        wq[j][cnt[SI_W-1:0]] <= aw_gnt_idx[j];
                        cnt = cnt + 1'b1;
                    end
                end else begin
                    // No queued entry: W may already be flowing against the
                    // pending, not-yet-accepted AW grant (aw_gnt_idx[j]).
                    if (aw_fire && wlast_fire) begin
                        w_done_pending[j] <= 1'b0;
                    end else if (wlast_fire) begin
                        w_done_pending[j] <= 1'b1;
                    end else if (aw_fire) begin
                        if (w_done_pending[j]) begin
                            w_done_pending[j] <= 1'b0;
                        end else begin
                            wq[j][0] <= aw_gnt_idx[j];
                            cnt = '0;
                            cnt[0] = 1'b1;
                        end
                    end
                end
                wq_cnt[j] <= cnt;
            end
        end
    end

    ///////////////
    // B and R   //
    ///////////////

    always_comb begin
        s_axi_bvalid = '0; s_axi_bid = '0; s_axi_bresp = '0; mi_axi_bready = '0;
        s_axi_rvalid = '0; s_axi_rid = '0; s_axi_rdata = '0; s_axi_rresp = '0; s_axi_rlast = '0; mi_axi_rready = '0;
        for (int j = 0; j < NUM_MI_E; j++) begin
            automatic int bi = int'(mi_axi_bid[j][SI_W-1:0]);
            automatic int ri = int'(mi_axi_rid[j][SI_W-1:0]);
            if (mi_axi_bvalid[j] && bi < NUM_SI) begin
                s_axi_bvalid[bi] = 1'b1;
                s_axi_bid[bi]    = wr_id[bi];
                s_axi_bresp[bi]  = mi_axi_bresp[j];
                mi_axi_bready[j]     = s_axi_bready[bi];
            end
            if (mi_axi_rvalid[j] && ri < NUM_SI) begin
                s_axi_rvalid[ri] = 1'b1;
                s_axi_rid[ri]    = rd_id[ri];
                s_axi_rdata[ri]  = mi_axi_rdata[j];
                s_axi_rresp[ri]  = mi_axi_rresp[j];
                s_axi_rlast[ri]  = mi_axi_rlast[j];
                mi_axi_rready[j]     = s_axi_rready[ri];
            end
        end
    end

    always_ff @(posedge aclk) begin
        if (!aresetn) begin
            wr_busy <= '0; rd_busy <= '0; aw_rr <= '0; ar_rr <= '0; wr_id <= '0; rd_id <= '0;
            aw_lock <= '0; ar_lock <= '0;
        end else begin
            for (int i = 0; i < NUM_SI; i++) begin
                if (s_axi_awvalid[i] && s_axi_awready[i]) begin wr_busy[i] <= 1'b1; wr_id[i] <= s_axi_awid[i]; end
                if (s_axi_bvalid[i] && s_axi_bready[i]) wr_busy[i] <= 1'b0;
                if (s_axi_arvalid[i] && s_axi_arready[i]) begin rd_busy[i] <= 1'b1; rd_id[i] <= s_axi_arid[i]; end
                if (s_axi_rvalid[i] && s_axi_rready[i] && s_axi_rlast[i]) rd_busy[i] <= 1'b0;
            end
            for (int j = 0; j < NUM_MI_E; j++) begin
                if (mi_axi_awvalid[j] && mi_axi_awready[j]) aw_rr[j] <= next_ptr(aw_gnt_idx[j]);
                if (mi_axi_arvalid[j] && mi_axi_arready[j]) ar_rr[j] <= next_ptr(ar_gnt_idx[j]);
                if (mi_axi_awvalid[j] && !mi_axi_awready[j]) begin aw_lock[j] <= 1'b1; aw_lock_idx[j] <= aw_gnt_idx[j]; end
                else aw_lock[j] <= 1'b0;
                if (mi_axi_arvalid[j] && !mi_axi_arready[j]) begin ar_lock[j] <= 1'b1; ar_lock_idx[j] <= ar_gnt_idx[j]; end
                else ar_lock[j] <= 1'b0;
            end
        end
    end

    //////////////////////////////
    // Master ports, error slave //
    //////////////////////////////

    assign mi_axi_awregion = '0;
    assign mi_axi_arregion = '0;
    `CONCAT_AXI_SLAVES_ARRAY2(mi, err, m)

    simplyv_axi_err_slv #(
        .DATA_WIDTH ( DATA_WIDTH ),
        .ADDR_WIDTH ( ADDR_WIDTH ),
        .ID_WIDTH   ( ID_WIDTH   )
    ) err_slv_u (
        .aclk, .aresetn,
        .s_axi_awid(err_axi_awid), .s_axi_awaddr(err_axi_awaddr), .s_axi_awlen(err_axi_awlen),
        .s_axi_awsize(err_axi_awsize), .s_axi_awburst(err_axi_awburst), .s_axi_awlock(err_axi_awlock),
        .s_axi_awcache(err_axi_awcache), .s_axi_awprot(err_axi_awprot), .s_axi_awqos(err_axi_awqos),
        .s_axi_awregion(err_axi_awregion), .s_axi_awvalid(err_axi_awvalid), .s_axi_awready(err_axi_awready),
        .s_axi_wdata(err_axi_wdata), .s_axi_wstrb(err_axi_wstrb), .s_axi_wlast(err_axi_wlast),
        .s_axi_wvalid(err_axi_wvalid), .s_axi_wready(err_axi_wready),
        .s_axi_bid(err_axi_bid), .s_axi_bresp(err_axi_bresp), .s_axi_bvalid(err_axi_bvalid), .s_axi_bready(err_axi_bready),
        .s_axi_arid(err_axi_arid), .s_axi_araddr(err_axi_araddr), .s_axi_arlen(err_axi_arlen),
        .s_axi_arsize(err_axi_arsize), .s_axi_arburst(err_axi_arburst), .s_axi_arlock(err_axi_arlock),
        .s_axi_arcache(err_axi_arcache), .s_axi_arprot(err_axi_arprot), .s_axi_arqos(err_axi_arqos),
        .s_axi_arregion(err_axi_arregion), .s_axi_arvalid(err_axi_arvalid), .s_axi_arready(err_axi_arready),
        .s_axi_rid(err_axi_rid), .s_axi_rdata(err_axi_rdata), .s_axi_rresp(err_axi_rresp),
        .s_axi_rlast(err_axi_rlast), .s_axi_rvalid(err_axi_rvalid), .s_axi_rready(err_axi_rready)
    );

endmodule
