// Author: Salvatore Bramante <salvatore.bramante@yahoo.it>
// Description: Simulation model of the Xilinx AXI4 64-to-32 data-width
//              downsizer. Transactions pass 1:1; the 32-bit lane is steered by
//              addr[2] (wdata/wstrb half selected, rdata replicated). W may come
//              before, with or after its AW. One outstanding write and one outstanding
//              read: AW waits for the previous B, AR for the previous last R.
//              Limit: single-beat, aligned, <=32-bit MMIO accesses.

`include "simplyv_axi.svh"

module xlnx_axi_dwidth_64_to_32_converter #(
    parameter int unsigned S_DATA_WIDTH = 64,
    parameter int unsigned M_DATA_WIDTH = 32,
    parameter int unsigned ADDR_WIDTH   = 32,
    parameter int unsigned ID_WIDTH     = 5
) (
    input logic s_axi_aclk,
    input logic s_axi_aresetn,

    // 64-bit slave (from MBUS)
    `DEFINE_AXI_SLAVE_PORTS(s, S_DATA_WIDTH, ADDR_WIDTH, ID_WIDTH),

    // 32-bit master (to peripheral) - no IDs (Xilinx IP omits them here)
    output logic [ADDR_WIDTH-1:0]   m_axi_awaddr,
    output axi_len_t                m_axi_awlen,
    output axi_size_t               m_axi_awsize,
    output axi_burst_t              m_axi_awburst,
    output axi_lock_t               m_axi_awlock,
    output axi_cache_t              m_axi_awcache,
    output axi_prot_t               m_axi_awprot,
    output axi_qos_t                m_axi_awqos,
    output axi_region_t             m_axi_awregion,
    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,
    output logic [M_DATA_WIDTH-1:0] m_axi_wdata,
    output logic [M_DATA_WIDTH/8-1:0] m_axi_wstrb,
    output logic                    m_axi_wlast,
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,
    input  axi_resp_code_t          m_axi_bresp,
    input  logic                    m_axi_bvalid,
    output logic                    m_axi_bready,
    output logic [ADDR_WIDTH-1:0]   m_axi_araddr,
    output axi_len_t                m_axi_arlen,
    output axi_size_t               m_axi_arsize,
    output axi_burst_t              m_axi_arburst,
    output axi_lock_t               m_axi_arlock,
    output axi_cache_t              m_axi_arcache,
    output axi_prot_t               m_axi_arprot,
    output axi_qos_t                m_axi_arqos,
    output axi_region_t             m_axi_arregion,
    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,
    input  logic [M_DATA_WIDTH-1:0] m_axi_rdata,
    input  axi_resp_code_t          m_axi_rresp,
    input  logic                    m_axi_rlast,
    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready
);

    // Write lane: addr[2] of the AW being presented, or of the accepted one until its W
    // completes. W passes only with an AW valid or accepted. AW is held from its
    // handshake to B and AR to the last R, so the IDs reflected on B/R are stable.
    logic                aw_lane_q, aw_pend_q, w_done_q, aw_fire, w_fire, w_open, w_lane;
    logic                b_pend_q, r_pend_q;
    logic [ID_WIDTH-1:0] aw_id_q, ar_id_q;

    assign aw_fire = s_axi_awvalid & s_axi_awready;
    assign w_fire  = m_axi_wvalid & m_axi_wready & m_axi_wlast;
    assign w_open  = (aw_pend_q | s_axi_awvalid) & ~w_done_q;
    assign w_lane  = aw_pend_q ? aw_lane_q : s_axi_awaddr[2];

    always_ff @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            aw_lane_q <= 1'b0;
            aw_pend_q <= 1'b0;
            w_done_q  <= 1'b0;
            b_pend_q  <= 1'b0;
            r_pend_q  <= 1'b0;
            aw_id_q   <= '0;
            ar_id_q   <= '0;
        end else begin
            if (aw_fire) begin
                aw_lane_q <= s_axi_awaddr[2];
                aw_id_q   <= s_axi_awid;
            end
            if (s_axi_arvalid && s_axi_arready) ar_id_q <= s_axi_arid;
            aw_pend_q <= aw_pend_q ? ~w_fire : aw_fire & ~w_fire & ~w_done_q;
            w_done_q  <= w_done_q  ? ~aw_fire : w_fire & ~aw_fire & ~aw_pend_q;
            b_pend_q  <= b_pend_q  ? ~(s_axi_bvalid & s_axi_bready) : aw_fire;
            r_pend_q  <= r_pend_q  ? ~(s_axi_rvalid & s_axi_rready & s_axi_rlast) : s_axi_arvalid & s_axi_arready;
        end
    end

    // AW and AR forwarded with 32-bit beats
    assign m_axi_awaddr   = s_axi_awaddr;
    assign m_axi_awlen    = s_axi_awlen;
    assign m_axi_awsize   = 3'd2;
    assign m_axi_awburst  = s_axi_awburst;
    assign m_axi_awlock   = s_axi_awlock;
    assign m_axi_awcache  = s_axi_awcache;
    assign m_axi_awprot   = s_axi_awprot;
    assign m_axi_awqos    = s_axi_awqos;
    assign m_axi_awregion = s_axi_awregion;
    assign m_axi_awvalid  = s_axi_awvalid & ~b_pend_q;
    assign s_axi_awready  = m_axi_awready & ~b_pend_q;

    assign m_axi_wdata  = w_lane ? s_axi_wdata[63:32] : s_axi_wdata[31:0];
    assign m_axi_wstrb  = w_lane ? s_axi_wstrb[7:4]   : s_axi_wstrb[3:0];
    assign m_axi_wlast  = s_axi_wlast;
    assign m_axi_wvalid = s_axi_wvalid & w_open;
    assign s_axi_wready = m_axi_wready & w_open;

    assign s_axi_bid    = aw_id_q;
    assign s_axi_bresp  = m_axi_bresp;
    assign s_axi_bvalid = m_axi_bvalid;
    assign m_axi_bready = s_axi_bready;

    assign m_axi_araddr   = s_axi_araddr;
    assign m_axi_arlen    = s_axi_arlen;
    assign m_axi_arsize   = 3'd2;
    assign m_axi_arburst  = s_axi_arburst;
    assign m_axi_arlock   = s_axi_arlock;
    assign m_axi_arcache  = s_axi_arcache;
    assign m_axi_arprot   = s_axi_arprot;
    assign m_axi_arqos    = s_axi_arqos;
    assign m_axi_arregion = s_axi_arregion;
    assign m_axi_arvalid  = s_axi_arvalid & ~r_pend_q;
    assign s_axi_arready  = m_axi_arready & ~r_pend_q;

    // Read data replicated on both 32-bit lanes
    assign s_axi_rid    = ar_id_q;
    assign s_axi_rdata  = {m_axi_rdata, m_axi_rdata};
    assign s_axi_rresp  = m_axi_rresp;
    assign s_axi_rlast  = m_axi_rlast;
    assign s_axi_rvalid = m_axi_rvalid;
    assign m_axi_rready = s_axi_rready;

endmodule
