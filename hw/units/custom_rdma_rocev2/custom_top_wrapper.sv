// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description: Top level wrapper for the RDMA RoCEv2 (lite) engine (network_wrapper_roce_generic).
//              The wrapper exposes:
//                - an AXI-lite slave (s_ctrl) to the control/status registers (CSR) of the engine;
//                - the Ethernet AXI-Stream TX/RX pair toward the MAC (e.g. the CMAC).
//
//              Clock domain: a single clock (clk_i/rst_ni) drives the CSR, the RoCE engine (clk_mac, clk_stack
//              and clk_roce_eng of network_wrapper_roce_generic) and the Ethernet AXI-Stream, i.e. the CMAC user clock.
//
//              NOTE: as-is, the engine has no memory interface: the payload comes from an internal data generator,
//              the retransmission buffer is an internal RAM, and QPs are opened/closed/started through connection
//              manager (CM) messages over UDP. To drive the engine without a host, the wrapper includes a CM frame
//              injector: software writes a whole Ethernet frame (e.g. a CM request) in INJ_BUF, sets INJ_LEN and
//              pulses CTRL.INJECT; the frame is then merged in the RX stream toward the engine, as if it came
//              from the network. Frames from the MAC have priority and are never interrupted.
//
//              CSR map (32-bit registers, only the address bits [8:2] are decoded):
//                0x000  ID                   RO  32'h5244_4D41 ("RDMA")
//                0x004  CTRL                 WO  [0] clear ARP cache (pulse), [1] QP spy request (pulse), [2] inject INJ_BUF (pulse)
//                0x008  STATUS               RO  [0] QP spy snapshot valid (cleared by a new spy request), [1] injector busy
//                0x00C  INJ_LEN              RW  [7:0] length in bytes of the frame in INJ_BUF (1 to 128)
//                0x010  MAC_LO               RW  local MAC address [31:0]
//                0x014  MAC_HI               RW  local MAC address [47:32] (in [15:0])
//                0x018  IP                   RW  local IPv4 address
//                0x01C  NET_CFG              RW  [15:0] RoCE UDP port, [18:16] PMTU, [22:20] priority tag
//                0x020  MON_QPN              RW  [23:0] local QPN observed by the perf monitor
//                0x024  MON_CFG              RW  [3:0] latency averaging (log2), [12:8] throughput averaging (log2)
//                0x030  MON_XFER_TIME_AVG    RO  transfer time, average
//                0x034  MON_XFER_TIME_MAVG   RO  transfer time, moving average
//                0x038  MON_LATENCY_AVG      RO  latency, average
//                0x03C  MON_LATENCY_MAVG     RO  latency, moving average
//                0x040  MON_PSN_DIFF         RO  [23:0] PSN difference (sent - acked)
//                0x044  MON_RETRANSMIT       RO  number of retransmission triggers
//                0x048  MON_RNR_RETRANSMIT   RO  number of RNR retransmission triggers
//                0x050  SPY_QPN              RW  [23:0] local QPN to snapshot on a QP spy request
//                0x054  SPY_STATE            RO  [2:0] QP state, [15:8] syndrome
//                0x058  SPY_LOC_QPN          RO  [23:0] local QPN
//                0x05C  SPY_REM_QPN          RO  [23:0] remote QPN
//                0x060  SPY_LOC_PSN          RO  [23:0] local PSN
//                0x064  SPY_REM_PSN          RO  [23:0] remote PSN
//                0x068  SPY_REM_ACKED_PSN    RO  [23:0] remote acked PSN
//                0x06C  SPY_R_KEY            RO  remote key
//                0x070  SPY_REM_ADDR_LO      RO  remote virtual address [31:0]
//                0x074  SPY_REM_ADDR_HI      RO  remote virtual address [63:32]
//                0x078  SPY_REM_IP           RO  remote IPv4 address
//                0x100  INJ_BUF[0..31]       RW  frame to inject: byte n of the frame (wire order) is byte (n % 4) of word (n / 4)
//              Unmapped offsets read as zero and ignore writes (the response is always OKAY).
//              The RW reset values are the ones of the upstream example design, so the engine is usable right after
//              reset, without any software configuration.
//              QP spy: only the QPNs handled by the engine (from 256 on) produce a snapshot, so poll STATUS with a timeout.


// Import headers
`include "simplyv_axi.svh"

module custom_top_wrapper # (

    //////////////////////////////////////
    //  Add here IP-related parameters  //
    //////////////////////////////////////

    // Ethernet AXI-Stream and RoCE stack data width (512 for the CMAC AXIS interface)
    parameter int unsigned  MAC_DATA_WIDTH                   = 512,
    // Data width of each QP channel (128 bits at 322 MHz is about 40 Gbps per QP, as in the upstream 100G example)
    parameter int unsigned  QP_CH_DATA_WIDTH                 = 128,
    // Number of queue pairs (power of two, at least 2)
    parameter int unsigned  N_QUEUE_PAIRS                    = 4,
    // Retransmission buffer size (2**N bytes)
    parameter int unsigned  RETRANSMISSION_ADDR_BUFFER_WIDTH = 21,

    // AXI-lite slave parameters
    localparam int unsigned LOCAL_AXILITE_DATA_WIDTH         = 32,
    localparam int unsigned LOCAL_AXILITE_ADDR_WIDTH         = 32

) (

    ///////////////////////////////////
    //  Add here IP-related signals  //
    ///////////////////////////////////

    // Clock and reset (CMAC user clock domain)
    input  logic                            clk_i,
    input  logic                            rst_ni,

    // Ethernet AXI-Stream TX toward the MAC
    output logic [MAC_DATA_WIDTH   -1 : 0]  m_eth_tx_axis_tdata,
    output logic [MAC_DATA_WIDTH/8 -1 : 0]  m_eth_tx_axis_tkeep,
    output logic                            m_eth_tx_axis_tvalid,
    input  logic                            m_eth_tx_axis_tready,
    output logic                            m_eth_tx_axis_tlast,
    output logic                            m_eth_tx_axis_tuser,

    // Ethernet AXI-Stream RX from the MAC
    input  logic [MAC_DATA_WIDTH   -1 : 0]  s_eth_rx_axis_tdata,
    input  logic [MAC_DATA_WIDTH/8 -1 : 0]  s_eth_rx_axis_tkeep,
    input  logic                            s_eth_rx_axis_tvalid,
    output logic                            s_eth_rx_axis_tready,
    input  logic                            s_eth_rx_axis_tlast,
    input  logic                            s_eth_rx_axis_tuser,

    ////////////////////////////
    //  Bus Array Interfaces  //
    ////////////////////////////

    // AXI-lite slave interface to the CSR
    `DEFINE_AXILITE_SLAVE_PORTS(s_ctrl, LOCAL_AXILITE_DATA_WIDTH, LOCAL_AXILITE_ADDR_WIDTH)

);

    //////////////////////////
    //  Local parameters    //
    //////////////////////////

    // Engine configuration fixed by this wrapper
    localparam logic [7:0]  ENABLE_PFC           = 8'h00;              // No PFC (not enabled on the CMAC)
    localparam int unsigned DEBUG                = 0;                  // DEBUG=1 needs Xilinx ILA/VIO IPs that are not part of the sources
    localparam int unsigned N_ROCE_TX_ENGINES    = 1;
    localparam int unsigned ASYNC_MAC_STACK      = 0;                  // MAC and stack share the same clock
    localparam real         ROCE_CLOCK_PERIOD_NS = 1000.0/322.265625;  // CMAC user clock, used for the RNR timers

    // CSR address decoding (byte offset = word index * 4)
    localparam int unsigned CSR_ADDR_LSB = 2;
    localparam int unsigned CSR_ADDR_MSB = 8;

    // CSR word indexes
    localparam logic [6:0]  CSR_ID                 = 7'h00; // 0x000
    localparam logic [6:0]  CSR_CTRL               = 7'h01; // 0x004
    localparam logic [6:0]  CSR_STATUS             = 7'h02; // 0x008
    localparam logic [6:0]  CSR_INJ_LEN            = 7'h03; // 0x00C
    localparam logic [6:0]  CSR_MAC_LO             = 7'h04; // 0x010
    localparam logic [6:0]  CSR_MAC_HI             = 7'h05; // 0x014
    localparam logic [6:0]  CSR_IP                 = 7'h06; // 0x018
    localparam logic [6:0]  CSR_NET_CFG            = 7'h07; // 0x01C
    localparam logic [6:0]  CSR_MON_QPN            = 7'h08; // 0x020
    localparam logic [6:0]  CSR_MON_CFG            = 7'h09; // 0x024
    localparam logic [6:0]  CSR_MON_XFER_TIME_AVG  = 7'h0C; // 0x030
    localparam logic [6:0]  CSR_MON_XFER_TIME_MAVG = 7'h0D; // 0x034
    localparam logic [6:0]  CSR_MON_LATENCY_AVG    = 7'h0E; // 0x038
    localparam logic [6:0]  CSR_MON_LATENCY_MAVG   = 7'h0F; // 0x03C
    localparam logic [6:0]  CSR_MON_PSN_DIFF       = 7'h10; // 0x040
    localparam logic [6:0]  CSR_MON_RETRANSMIT     = 7'h11; // 0x044
    localparam logic [6:0]  CSR_MON_RNR_RETRANSMIT = 7'h12; // 0x048
    localparam logic [6:0]  CSR_SPY_QPN            = 7'h14; // 0x050
    localparam logic [6:0]  CSR_SPY_STATE          = 7'h15; // 0x054
    localparam logic [6:0]  CSR_SPY_LOC_QPN        = 7'h16; // 0x058
    localparam logic [6:0]  CSR_SPY_REM_QPN        = 7'h17; // 0x05C
    localparam logic [6:0]  CSR_SPY_LOC_PSN        = 7'h18; // 0x060
    localparam logic [6:0]  CSR_SPY_REM_PSN        = 7'h19; // 0x064
    localparam logic [6:0]  CSR_SPY_REM_ACKED_PSN  = 7'h1A; // 0x068
    localparam logic [6:0]  CSR_SPY_R_KEY          = 7'h1B; // 0x06C
    localparam logic [6:0]  CSR_SPY_REM_ADDR_LO    = 7'h1C; // 0x070
    localparam logic [6:0]  CSR_SPY_REM_ADDR_HI    = 7'h1D; // 0x074
    localparam logic [6:0]  CSR_SPY_REM_IP         = 7'h1E; // 0x078
    localparam logic [1:0]  CSR_INJ_BUF_PAGE       = 2'b10; // 0x100 - 0x17C, i.e. word indexes 7'h40 - 7'h5F

    // ID register value
    localparam logic [31:0] CSR_ID_VALUE = 32'h5244_4D41; // "RDMA"

    // CTRL and STATUS bit positions
    localparam int unsigned CTRL_CLEAR_ARP_BIT    = 0;
    localparam int unsigned CTRL_SPY_REQ_BIT      = 1;
    localparam int unsigned CTRL_INJECT_BIT       = 2;
    localparam int unsigned STATUS_SPY_VALID_BIT  = 0;
    localparam int unsigned STATUS_INJ_BUSY_BIT   = 1;

    // Injector buffer: 32 words (128 bytes), sent as INJ_BEATS beats of MAC_DATA_WIDTH bits
    localparam int unsigned INJ_BUF_WORDS  = 32;
    localparam int unsigned INJ_BUF_BYTES  = INJ_BUF_WORDS * 4;
    localparam int unsigned INJ_BEAT_BYTES = MAC_DATA_WIDTH / 8;
    localparam int unsigned INJ_BEATS      = INJ_BUF_BYTES / INJ_BEAT_BYTES;
    localparam int unsigned INJ_BEAT_WORDS = INJ_BEAT_BYTES / 4;

    // RW registers reset values (upstream example design)
    localparam logic [47:0] RST_LOCAL_MAC   = 48'h00_0A_35_DE_AD_01;
    localparam logic [31:0] RST_LOCAL_IP    = {8'd22, 8'd1, 8'd212, 8'd10}; // 22.1.212.10
    localparam logic [15:0] RST_UDP_PORT    = 16'd4791;                     // RoCEv2 UDP port
    localparam logic [2:0]  RST_PMTU        = 3'd4;                         // 0: 256 B, ..., 4: 4096 B
    localparam logic [2:0]  RST_PRIO_TAG    = 3'd1;
    localparam logic [23:0] RST_MON_QPN     = 24'd256;                      // First QPN of the engine
    localparam logic [3:0]  RST_LAT_AVG_PO2 = 4'd4;
    localparam logic [4:0]  RST_THR_AVG_PO2 = 5'd4;
    localparam logic [23:0] RST_SPY_QPN     = 24'd256;

    /////////////////////
    //  Local signals  //
    /////////////////////

    // Active-high reset for the engine
    logic        rst;

    // AXI-lite handshakes
    logic        aw_w_ready_q;
    logic        write_en;
    logic [6:0]  write_idx;
    logic        write_inj_buf;
    logic [31:0] write_old_value;
    logic [31:0] write_new_value;
    logic        ar_ready_q;
    logic        read_en;
    logic [6:0]  read_idx;
    logic        read_inj_buf;
    logic [31:0] read_value;

    // Control registers
    logic [47:0] ctrl_local_mac_q;
    logic [31:0] ctrl_local_ip_q;
    logic [15:0] ctrl_udp_port_q;
    logic [2:0]  ctrl_pmtu_q;
    logic [2:0]  ctrl_prio_tag_q;
    logic        ctrl_clear_arp_q;      // One-cycle pulse

    // Perf monitor
    logic [23:0] mon_qpn_q;
    logic [3:0]  mon_lat_avg_po2_q;
    logic [4:0]  mon_thr_avg_po2_q;
    logic [31:0] mon_xfer_time_avg;
    logic [31:0] mon_xfer_time_mavg;
    logic [31:0] mon_latency_avg;
    logic [31:0] mon_latency_mavg;
    logic [23:0] mon_psn_diff;
    logic [31:0] mon_retransmit;
    logic [31:0] mon_rnr_retransmit;

    // QP spy request
    logic [23:0] spy_qpn_q;
    logic        spy_req_q;             // One-cycle pulse
    // QP spy response from the engine
    logic        spy_context_valid;
    logic [2:0]  spy_state;
    logic [23:0] spy_rem_qpn;
    logic [23:0] spy_loc_qpn;
    logic [23:0] spy_rem_psn;
    logic [23:0] spy_rem_acked_psn;
    logic [23:0] spy_loc_psn;
    logic [31:0] spy_r_key;
    logic [63:0] spy_rem_addr;
    logic [31:0] spy_rem_ip_addr;
    logic [7:0]  spy_syndrome;
    // QP spy snapshot
    logic        spy_valid_q;
    logic [2:0]  spy_state_q;
    logic [23:0] spy_rem_qpn_q;
    logic [23:0] spy_loc_qpn_q;
    logic [23:0] spy_rem_psn_q;
    logic [23:0] spy_rem_acked_psn_q;
    logic [23:0] spy_loc_psn_q;
    logic [31:0] spy_r_key_q;
    logic [63:0] spy_rem_addr_q;
    logic [31:0] spy_rem_ip_addr_q;
    logic [7:0]  spy_syndrome_q;

    // Injector
    logic [31:0] inj_buf_q [INJ_BUF_WORDS];
    logic [7:0]  inj_len_q;
    logic        inj_start_q;           // One-cycle pulse
    logic        inj_busy_q;
    logic [$clog2(INJ_BEATS)-1:0] inj_beat_q;
    logic [8:0]  inj_bytes_left;
    logic        inj_last_beat;

    // RW registers as seen on the bus
    logic [31:0] csr_mac_lo;
    logic [31:0] csr_mac_hi;
    logic [31:0] csr_ip;
    logic [31:0] csr_net_cfg;
    logic [31:0] csr_mon_qpn;
    logic [31:0] csr_mon_cfg;
    logic [31:0] csr_spy_qpn;

    ////////////////////////
    //  AXI-Stream buses  //
    ////////////////////////

    // MAC RX buffered (to absorb the few cycles in which the injector owns the RX stream)
    logic [MAC_DATA_WIDTH   -1 : 0]  rx_fifo_axis_tdata;
    logic [MAC_DATA_WIDTH/8 -1 : 0]  rx_fifo_axis_tkeep;
    logic                            rx_fifo_axis_tvalid;
    logic                            rx_fifo_axis_tready;
    logic                            rx_fifo_axis_tlast;
    logic                            rx_fifo_axis_tuser;

    // Injector output
    logic [MAC_DATA_WIDTH   -1 : 0]  inj_axis_tdata;
    logic [MAC_DATA_WIDTH/8 -1 : 0]  inj_axis_tkeep;
    logic                            inj_axis_tvalid;
    logic                            inj_axis_tready;
    logic                            inj_axis_tlast;

    // RX stream toward the engine
    logic [MAC_DATA_WIDTH   -1 : 0]  rx_engine_axis_tdata;
    logic [MAC_DATA_WIDTH/8 -1 : 0]  rx_engine_axis_tkeep;
    logic                            rx_engine_axis_tvalid;
    logic                            rx_engine_axis_tready;
    logic                            rx_engine_axis_tlast;
    logic                            rx_engine_axis_tuser;

    /////////////////////////
    //  Local assignments  //
    /////////////////////////

    assign rst         = ~rst_ni;

    assign csr_mac_lo  = ctrl_local_mac_q[31:0];
    assign csr_mac_hi  = {16'b0, ctrl_local_mac_q[47:32]};
    assign csr_ip      = ctrl_local_ip_q;
    assign csr_net_cfg = {9'b0, ctrl_prio_tag_q, 1'b0, ctrl_pmtu_q, ctrl_udp_port_q};
    assign csr_mon_qpn = {8'b0, mon_qpn_q};
    assign csr_mon_cfg = {19'b0, mon_thr_avg_po2_q, 4'b0, mon_lat_avg_po2_q};
    assign csr_spy_qpn = {8'b0, spy_qpn_q};

    ///////////////////////////
    //  AXI-lite write path  //
    ///////////////////////////

    // Accept AW and W together (one transaction at a time), then answer on B
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            aw_w_ready_q          <= 1'b0;
            s_ctrl_axilite_bvalid <= 1'b0;
        end
        else begin
            aw_w_ready_q <= s_ctrl_axilite_awvalid & s_ctrl_axilite_wvalid & ~aw_w_ready_q & ~s_ctrl_axilite_bvalid;

            if (write_en)
                s_ctrl_axilite_bvalid <= 1'b1;
            else if (s_ctrl_axilite_bready)
                s_ctrl_axilite_bvalid <= 1'b0;
        end
    end

    assign s_ctrl_axilite_awready = aw_w_ready_q;
    assign s_ctrl_axilite_wready  = aw_w_ready_q;
    assign s_ctrl_axilite_bresp   = 2'b00; // OKAY

    assign write_en  = aw_w_ready_q & s_ctrl_axilite_awvalid & s_ctrl_axilite_wvalid;
    assign write_idx = s_ctrl_axilite_awaddr[CSR_ADDR_MSB:CSR_ADDR_LSB];
    assign write_inj_buf = (write_idx[6:5] == CSR_INJ_BUF_PAGE);

    // Merge the written bytes (wstrb) with the current register value
    always_comb begin
        if (write_inj_buf)
            write_old_value = inj_buf_q[write_idx[4:0]];
        else begin
            case (write_idx)
                CSR_INJ_LEN : write_old_value = {24'b0, inj_len_q};
                CSR_MAC_LO  : write_old_value = csr_mac_lo;
                CSR_MAC_HI  : write_old_value = csr_mac_hi;
                CSR_IP      : write_old_value = csr_ip;
                CSR_NET_CFG : write_old_value = csr_net_cfg;
                CSR_MON_QPN : write_old_value = csr_mon_qpn;
                CSR_MON_CFG : write_old_value = csr_mon_cfg;
                CSR_SPY_QPN : write_old_value = csr_spy_qpn;
                default     : write_old_value = '0;
            endcase
        end

        for (int i = 0; i < 4; i++) begin
            write_new_value[8*i +: 8] = s_ctrl_axilite_wstrb[i] ? s_ctrl_axilite_wdata[8*i +: 8] : write_old_value[8*i +: 8];
        end
    end

    // Control registers
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ctrl_local_mac_q  <= RST_LOCAL_MAC;
            ctrl_local_ip_q   <= RST_LOCAL_IP;
            ctrl_udp_port_q   <= RST_UDP_PORT;
            ctrl_pmtu_q       <= RST_PMTU;
            ctrl_prio_tag_q   <= RST_PRIO_TAG;
            ctrl_clear_arp_q  <= 1'b0;
            mon_qpn_q         <= RST_MON_QPN;
            mon_lat_avg_po2_q <= RST_LAT_AVG_PO2;
            mon_thr_avg_po2_q <= RST_THR_AVG_PO2;
            spy_qpn_q         <= RST_SPY_QPN;
            spy_req_q         <= 1'b0;
            inj_len_q         <= '0;
            inj_start_q       <= 1'b0;
            for (int i = 0; i < INJ_BUF_WORDS; i++) inj_buf_q[i] <= '0;
        end
        else begin
            // Pulses last one cycle
            ctrl_clear_arp_q <= 1'b0;
            spy_req_q        <= 1'b0;
            inj_start_q      <= 1'b0;

            if (write_en) begin
                if (write_inj_buf)
                    inj_buf_q[write_idx[4:0]] <= write_new_value;
                else begin
                    case (write_idx)
                        CSR_CTRL : begin
                            if (s_ctrl_axilite_wstrb[0]) begin
                                ctrl_clear_arp_q <= s_ctrl_axilite_wdata[CTRL_CLEAR_ARP_BIT];
                                spy_req_q        <= s_ctrl_axilite_wdata[CTRL_SPY_REQ_BIT];
                                inj_start_q      <= s_ctrl_axilite_wdata[CTRL_INJECT_BIT];
                            end
                        end
                        CSR_INJ_LEN : inj_len_q               <= write_new_value[7:0];
                        CSR_MAC_LO  : ctrl_local_mac_q[31:0]  <= write_new_value;
                        CSR_MAC_HI  : ctrl_local_mac_q[47:32] <= write_new_value[15:0];
                        CSR_IP      : ctrl_local_ip_q         <= write_new_value;
                        CSR_NET_CFG : begin
                            ctrl_udp_port_q <= write_new_value[15:0];
                            ctrl_pmtu_q     <= write_new_value[18:16];
                            ctrl_prio_tag_q <= write_new_value[22:20];
                        end
                        CSR_MON_QPN : mon_qpn_q               <= write_new_value[23:0];
                        CSR_MON_CFG : begin
                            mon_lat_avg_po2_q <= write_new_value[3:0];
                            mon_thr_avg_po2_q <= write_new_value[12:8];
                        end
                        CSR_SPY_QPN : spy_qpn_q               <= write_new_value[23:0];
                        default     : ; // Read-only or unmapped
                    endcase
                end
            end
        end
    end

    //////////////////////////
    //  AXI-lite read path  //
    //////////////////////////

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ar_ready_q            <= 1'b0;
            s_ctrl_axilite_rvalid <= 1'b0;
            s_ctrl_axilite_rdata  <= '0;
        end
        else begin
            ar_ready_q <= s_ctrl_axilite_arvalid & ~ar_ready_q & ~s_ctrl_axilite_rvalid;

            if (read_en) begin
                s_ctrl_axilite_rvalid <= 1'b1;
                s_ctrl_axilite_rdata  <= read_value;
            end
            else if (s_ctrl_axilite_rready) begin
                s_ctrl_axilite_rvalid <= 1'b0;
            end
        end
    end

    assign s_ctrl_axilite_arready = ar_ready_q;
    assign s_ctrl_axilite_rresp   = 2'b00; // OKAY

    assign read_en  = ar_ready_q & s_ctrl_axilite_arvalid;
    assign read_idx = s_ctrl_axilite_araddr[CSR_ADDR_MSB:CSR_ADDR_LSB];
    assign read_inj_buf = (read_idx[6:5] == CSR_INJ_BUF_PAGE);

    // Read multiplexer
    always_comb begin
        read_value = '0;
        if (read_inj_buf)
            read_value = inj_buf_q[read_idx[4:0]];
        else begin
            case (read_idx)
                CSR_ID                 : read_value = CSR_ID_VALUE;
                CSR_STATUS             : begin
                    read_value[STATUS_SPY_VALID_BIT] = spy_valid_q;
                    read_value[STATUS_INJ_BUSY_BIT]  = inj_busy_q;
                end
                CSR_INJ_LEN            : read_value = {24'b0, inj_len_q};
                CSR_MAC_LO             : read_value = csr_mac_lo;
                CSR_MAC_HI             : read_value = csr_mac_hi;
                CSR_IP                 : read_value = csr_ip;
                CSR_NET_CFG            : read_value = csr_net_cfg;
                CSR_MON_QPN            : read_value = csr_mon_qpn;
                CSR_MON_CFG            : read_value = csr_mon_cfg;
                CSR_MON_XFER_TIME_AVG  : read_value = mon_xfer_time_avg;
                CSR_MON_XFER_TIME_MAVG : read_value = mon_xfer_time_mavg;
                CSR_MON_LATENCY_AVG    : read_value = mon_latency_avg;
                CSR_MON_LATENCY_MAVG   : read_value = mon_latency_mavg;
                CSR_MON_PSN_DIFF       : read_value = {8'b0, mon_psn_diff};
                CSR_MON_RETRANSMIT     : read_value = mon_retransmit;
                CSR_MON_RNR_RETRANSMIT : read_value = mon_rnr_retransmit;
                CSR_SPY_QPN            : read_value = csr_spy_qpn;
                CSR_SPY_STATE          : read_value = {16'b0, spy_syndrome_q, 5'b0, spy_state_q};
                CSR_SPY_LOC_QPN        : read_value = {8'b0, spy_loc_qpn_q};
                CSR_SPY_REM_QPN        : read_value = {8'b0, spy_rem_qpn_q};
                CSR_SPY_LOC_PSN        : read_value = {8'b0, spy_loc_psn_q};
                CSR_SPY_REM_PSN        : read_value = {8'b0, spy_rem_psn_q};
                CSR_SPY_REM_ACKED_PSN  : read_value = {8'b0, spy_rem_acked_psn_q};
                CSR_SPY_R_KEY          : read_value = spy_r_key_q;
                CSR_SPY_REM_ADDR_LO    : read_value = spy_rem_addr_q[31:0];
                CSR_SPY_REM_ADDR_HI    : read_value = spy_rem_addr_q[63:32];
                CSR_SPY_REM_IP         : read_value = spy_rem_ip_addr_q;
                default                : read_value = '0;
            endcase
        end
    end

    //////////////////////
    //  QP spy snapshot //
    //////////////////////

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            spy_valid_q         <= 1'b0;
            spy_state_q         <= '0;
            spy_rem_qpn_q       <= '0;
            spy_loc_qpn_q       <= '0;
            spy_rem_psn_q       <= '0;
            spy_rem_acked_psn_q <= '0;
            spy_loc_psn_q       <= '0;
            spy_r_key_q         <= '0;
            spy_rem_addr_q      <= '0;
            spy_rem_ip_addr_q   <= '0;
            spy_syndrome_q      <= '0;
        end
        else begin
            if (spy_context_valid) begin
                spy_valid_q         <= 1'b1;
                spy_state_q         <= spy_state;
                spy_rem_qpn_q       <= spy_rem_qpn;
                spy_loc_qpn_q       <= spy_loc_qpn;
                spy_rem_psn_q       <= spy_rem_psn;
                spy_rem_acked_psn_q <= spy_rem_acked_psn;
                spy_loc_psn_q       <= spy_loc_psn;
                spy_r_key_q         <= spy_r_key;
                spy_rem_addr_q      <= spy_rem_addr;
                spy_rem_ip_addr_q   <= spy_rem_ip_addr;
                spy_syndrome_q      <= spy_syndrome;
            end
            // A new request invalidates the previous snapshot
            if (spy_req_q)
                spy_valid_q <= 1'b0;
        end
    end

    ///////////////////////////
    //  CM frame injector    //
    ///////////////////////////

    // Bytes of the frame still to send, from the current beat on
    assign inj_bytes_left = ((9'(inj_len_q) > 9'(INJ_BUF_BYTES)) ? 9'(INJ_BUF_BYTES) : 9'(inj_len_q)) - 9'(inj_beat_q * INJ_BEAT_BYTES);
    assign inj_last_beat  = (inj_bytes_left <= 9'(INJ_BEAT_BYTES));

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            inj_busy_q <= 1'b0;
            inj_beat_q <= '0;
        end
        else begin
            if (!inj_busy_q) begin
                inj_beat_q <= '0;
                // Start only with a non-empty frame
                if (inj_start_q && inj_len_q != '0)
                    inj_busy_q <= 1'b1;
            end
            else if (inj_axis_tvalid && inj_axis_tready) begin
                if (inj_last_beat)
                    inj_busy_q <= 1'b0;
                else
                    inj_beat_q <= inj_beat_q + 1'b1;
            end
        end
    end

    // Current beat: words [INJ_BEAT_WORDS*beat +: INJ_BEAT_WORDS] of the buffer
    always_comb begin
        for (int w = 0; w < INJ_BEAT_WORDS; w++) begin
            inj_axis_tdata[32*w +: 32] = inj_buf_q[INJ_BEAT_WORDS*inj_beat_q + w];
        end
        for (int b = 0; b < INJ_BEAT_BYTES; b++) begin
            inj_axis_tkeep[b] = (b < inj_bytes_left);
        end
    end

    assign inj_axis_tvalid = inj_busy_q;
    assign inj_axis_tlast  = inj_last_beat;

    // Small FIFO on the MAC RX side: the MAC cannot be stalled
    axis_srl_fifo #(
        .DATA_WIDTH     ( MAC_DATA_WIDTH       ),
        .KEEP_ENABLE    ( 1                    ),
        .KEEP_WIDTH     ( MAC_DATA_WIDTH/8     ),
        .LAST_ENABLE    ( 1                    ),
        .ID_ENABLE      ( 0                    ),
        .DEST_ENABLE    ( 0                    ),
        .USER_ENABLE    ( 1                    ),
        .USER_WIDTH     ( 1                    ),
        .DEPTH          ( 8                    )
    ) rx_mac_fifo_u (
        .clk            ( clk_i                ),
        .rst            ( rst                  ),
        // AXI input
        .s_axis_tdata   ( s_eth_rx_axis_tdata  ),
        .s_axis_tkeep   ( s_eth_rx_axis_tkeep  ),
        .s_axis_tvalid  ( s_eth_rx_axis_tvalid ),
        .s_axis_tready  ( s_eth_rx_axis_tready ),
        .s_axis_tlast   ( s_eth_rx_axis_tlast  ),
        .s_axis_tid     ( '0                   ),
        .s_axis_tdest   ( '0                   ),
        .s_axis_tuser   ( s_eth_rx_axis_tuser  ),
        // AXI output
        .m_axis_tdata   ( rx_fifo_axis_tdata   ),
        .m_axis_tkeep   ( rx_fifo_axis_tkeep   ),
        .m_axis_tvalid  ( rx_fifo_axis_tvalid  ),
        .m_axis_tready  ( rx_fifo_axis_tready  ),
        .m_axis_tlast   ( rx_fifo_axis_tlast   ),
        .m_axis_tid     (                      ),
        .m_axis_tdest   (                      ),
        .m_axis_tuser   ( rx_fifo_axis_tuser   ),
        // Status
        .count          (                      )
    );

    // Frame-based arbitration between MAC RX (port 0, higher priority) and injector (port 1)
    axis_arb_mux #(
        .S_COUNT                ( 2                ),
        .DATA_WIDTH             ( MAC_DATA_WIDTH   ),
        .KEEP_ENABLE            ( 1                ),
        .KEEP_WIDTH             ( MAC_DATA_WIDTH/8 ),
        .ID_ENABLE              ( 0                ),
        .DEST_ENABLE            ( 0                ),
        .USER_ENABLE            ( 1                ),
        .USER_WIDTH             ( 1                ),
        .LAST_ENABLE            ( 1                ),
        .ARB_TYPE_ROUND_ROBIN   ( 0                ),
        .ARB_LSB_HIGH_PRIORITY  ( 1                )
    ) rx_arb_mux_u (
        .clk            ( clk_i                                      ),
        .rst            ( rst                                        ),
        // AXI inputs
        .s_axis_tdata   ( {inj_axis_tdata,  rx_fifo_axis_tdata}      ),
        .s_axis_tkeep   ( {inj_axis_tkeep,  rx_fifo_axis_tkeep}      ),
        .s_axis_tvalid  ( {inj_axis_tvalid, rx_fifo_axis_tvalid}     ),
        .s_axis_tready  ( {inj_axis_tready, rx_fifo_axis_tready}     ),
        .s_axis_tlast   ( {inj_axis_tlast,  rx_fifo_axis_tlast}      ),
        .s_axis_tid     ( '0                                         ),
        .s_axis_tdest   ( '0                                         ),
        .s_axis_tuser   ( {1'b0,            rx_fifo_axis_tuser}      ),
        // AXI output
        .m_axis_tdata   ( rx_engine_axis_tdata                       ),
        .m_axis_tkeep   ( rx_engine_axis_tkeep                       ),
        .m_axis_tvalid  ( rx_engine_axis_tvalid                      ),
        .m_axis_tready  ( rx_engine_axis_tready                      ),
        .m_axis_tlast   ( rx_engine_axis_tlast                       ),
        .m_axis_tid     (                                            ),
        .m_axis_tdest   (                                            ),
        .m_axis_tuser   ( rx_engine_axis_tuser                       )
    );

    ///////////////////////
    //  RDMA RoCE engine //
    ///////////////////////

    network_wrapper_roce_generic #(
        .MAC_DATA_WIDTH                     ( MAC_DATA_WIDTH                   ),
        .STACK_DATA_WIDTH                   ( MAC_DATA_WIDTH                   ),
        .QP_CH_DATA_WIDTH                   ( QP_CH_DATA_WIDTH                 ),
        .R0CE_ENG_CLK_PERIOD                ( ROCE_CLOCK_PERIOD_NS             ),
        .N_ROCE_TX_ENGINES                  ( N_ROCE_TX_ENGINES                ),
        .N_QUEUE_PAIRS                      ( N_QUEUE_PAIRS                    ),
        .RETRANSMISSION_ADDR_BUFFER_WIDTH   ( RETRANSMISSION_ADDR_BUFFER_WIDTH ),
        .ASYNC_MAC_STACK                    ( ASYNC_MAC_STACK                  ),
        .ENABLE_PFC                         ( ENABLE_PFC                       ),
        .DEBUG                              ( DEBUG                            )
    ) network_wrapper_roce_generic_u (
        // Clocks and resets
        .clk_mac                    ( clk_i                 ),
        .rst_mac                    ( rst                   ),
        .clk_stack                  ( clk_i                 ),
        .rst_stack                  ( rst                   ),
        .clk_roce_eng               ( clk_i                 ),
        .rst_roce_eng               ( rst                   ),
        .flow_ctrl_pause            ( 1'b0                  ),

        // Ethernet AXI-Stream TX
        .m_network_tx_axis_tdata    ( m_eth_tx_axis_tdata   ),
        .m_network_tx_axis_tkeep    ( m_eth_tx_axis_tkeep   ),
        .m_network_tx_axis_tvalid   ( m_eth_tx_axis_tvalid  ),
        .m_network_tx_axis_tready   ( m_eth_tx_axis_tready  ),
        .m_network_tx_axis_tlast    ( m_eth_tx_axis_tlast   ),
        .m_network_tx_axis_tuser    ( m_eth_tx_axis_tuser   ),

        // Ethernet AXI-Stream RX (MAC + injector)
        .s_network_rx_axis_tdata    ( rx_engine_axis_tdata  ),
        .s_network_rx_axis_tkeep    ( rx_engine_axis_tkeep  ),
        .s_network_rx_axis_tvalid   ( rx_engine_axis_tvalid ),
        .s_network_rx_axis_tready   ( rx_engine_axis_tready ),
        .s_network_rx_axis_tlast    ( rx_engine_axis_tlast  ),
        .s_network_rx_axis_tuser    ( rx_engine_axis_tuser  ),

        // PFC (disabled)
        .pfc_pause_req              ( 8'h00                 ),
        .pfc_pause_ack              (                       ),

        // QP spy
        .m_qp_context_spy           ( spy_req_q             ),
        .m_qp_local_qpn_spy         ( spy_qpn_q             ),
        .s_qp_spy_context_valid     ( spy_context_valid     ),
        .s_qp_spy_state             ( spy_state             ),
        .s_qp_spy_rem_qpn           ( spy_rem_qpn           ),
        .s_qp_spy_loc_qpn           ( spy_loc_qpn           ),
        .s_qp_spy_rem_psn           ( spy_rem_psn           ),
        .s_qp_spy_rem_acked_psn     ( spy_rem_acked_psn     ),
        .s_qp_spy_loc_psn           ( spy_loc_psn           ),
        .s_qp_spy_r_key             ( spy_r_key             ),
        .s_qp_spy_rem_addr          ( spy_rem_addr          ),
        .s_qp_spy_rem_ip_addr       ( spy_rem_ip_addr       ),
        .s_qp_spy_syndrome          ( spy_syndrome          ),

        // Control registers
        .ctrl_local_mac_address     ( ctrl_local_mac_q      ),
        .ctrl_local_ip              ( ctrl_local_ip_q       ),
        .ctrl_clear_arp_cache       ( ctrl_clear_arp_q      ),
        .ctrl_pmtu                  ( ctrl_pmtu_q           ),
        .ctrl_RoCE_udp_port         ( ctrl_udp_port_q       ),
        .ctrl_priority_tag          ( ctrl_prio_tag_q       ),

        // Perf monitor
        .cfg_latency_avg_po2        ( mon_lat_avg_po2_q     ),
        .cfg_throughput_avg_po2     ( mon_thr_avg_po2_q     ),
        .monitor_loc_qpn            ( mon_qpn_q             ),
        .transfer_time_avg          ( mon_xfer_time_avg     ),
        .transfer_time_moving_avg   ( mon_xfer_time_mavg    ),
        .latency_avg                ( mon_latency_avg       ),
        .latency_moving_avg         ( mon_latency_mavg      ),
        .psn_diff                   ( mon_psn_diff          ),
        .n_retransmit_triggers      ( mon_retransmit        ),
        .n_rnr_retransmit_triggers  ( mon_rnr_retransmit    )
    );

endmodule : custom_top_wrapper
