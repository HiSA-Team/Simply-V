// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description: Top level wrapper for the RDMA RoCEv2 (lite) engine with the RDMA WRITE responder (RoCE_ext_network_wrapper,
//              from SimplyV_Custom_RDMA/ext; the upstream engine is network_wrapper_roce_generic).
//              The wrapper exposes:
//                - an AXI-lite slave (s_ctrl) to the control/status registers (CSR) of the engine;
//                - the Ethernet AXI-Stream TX/RX pair toward the MAC (e.g. the CMAC).
//              The RDMA WRITE requests received from the network are written by the responder into a dedicated
//              receive buffer (RX buffer, block RAM, RXBUF_BYTES), readable by the processor through the CSR.
//              The transmit buffer (TX buffer, block RAM, TXBUF_BYTES) holds the payload of the messages to send:
//              the processor writes it through the CSR, the requester data source (RoCE_ext_tx_source) reads it
//              through an AXI4 read port of 512 bits.
//              TX data source of each QP (TX_CFG[3:0]): the internal data generator of the engine (default, started by
//              the CM START requests) or the work request / payload ports of the engine, fed by RoCE_ext_tx_source:
//              software posts one descriptor per RDMA WRITE (TX_DESC_*: TX buffer address, length, QP, remote
//              address, immediate), the data source reads the payload from the TX buffer and hands the work request
//              and the payload to the QP, in posting order.
//              The responder tables (QP context, memory regions) are written by software at initialization.
//
//              Clock domain: a single clock (clk_i/rst_ni) drives the CSR, the RoCE engine (clk_mac, clk_stack
//              and clk_roce_eng of the engine), the RX and TX buffers and the Ethernet AXI-Stream, i.e. the CMAC user
//              clock.
//
//              NOTE: as-is, the engine has no memory interface: the payload comes from an internal data generator,
//              the retransmission buffer is an internal RAM, and QPs are opened/closed/started through connection
//              manager (CM) messages over UDP. To drive the engine without a host, the wrapper includes a CM frame
//              injector: software writes a whole Ethernet frame (e.g. a CM request) in INJ_BUF, sets INJ_LEN and
//              pulses CTRL.INJECT; the frame is then merged in the RX stream toward the engine, as if it came
//              from the network. Frames from the MAC have priority and are never interrupted.
//
//              The frames toward the MAC are padded to the minimum Ethernet frame size (60 bytes + FCS) by cmac_pad,
//              as in the upstream 100G example: the CMAC does not pad, and the engine sends 42-byte ARP frames.
//
//              CSR map (32-bit registers, address bits [15:2] decoded, 64 KB window):
//                0x000  ID                   RO  32'h5244_4D41 ("RDMA")
//                0x004  CTRL                 WO  [0] clear ARP cache (pulse), [1] QP spy request (pulse), [2] inject INJ_BUF (pulse),
//                                                [3] engine reset (pulse: engine, RX/TX streams and RX buffer logic held in reset for
//                                                ENGINE_RST_CYCLES; the CSR keep their values; use it with the link idle),
//                                                [4] clear the RX buffer (pulse), [5] clear the PERF monitor (pulse)
//                0x008  STATUS               RO  [0] QP spy snapshot valid (cleared by a new spy request), [1] injector busy,
//                                                [2] engine reset in progress, [3] RX buffer clear in progress
//                0x00C  INJ_LEN              RW  [7:0] length in bytes of the frame in INJ_BUF (1 to 128)
//                0x010  MAC_LO               RW  local MAC address [31:0]
//                0x014  MAC_HI               RW  local MAC address [47:32] (in [15:0])
//                0x018  IP                   RW  local IPv4 address
//                0x01C  NET_CFG              RW  [15:0] RoCE UDP port, [18:16] PMTU, [22:20] priority tag
//                0x020  MON_QPN              RW  [23:0] local QPN observed by the upstream perf monitor
//                0x024  MON_CFG              RW  [3:0] latency averaging (log2), [12:8] throughput averaging (log2)
//                                                (MON_*: upstream monitor, generated only with DEBUG=1, i.e. it reads 0 here)
//                0x028  RXBUF_SIZE           RO  size of the RX buffer in bytes
//                0x02C  TXBUF_SIZE           RO  size of the TX buffer in bytes
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
//                0x080  PERF_CFG             RW  [0] RX buffer wrap: responder addresses taken modulo RXBUF_BYTES (long
//                                                runs over a larger MR, data overwritten), [1] PERF role: 0 requester
//                                                (WRITE on TX, ACK/NAK on RX), 1 responder (WRITE on RX, ACK/NAK on TX)
//                0x084  PERF_STATUS          RO  [0] overflow (more than PERF_FIFO_DEPTH WRITE waiting for their ACK),
//                                                [1] ACK/NAK without a WRITE waiting, [25:16] WRITE waiting for their ACK
//                0x088  PERF_CYCLES          RO  free-running clock cycle counter (clk_i)
//                0x08C  PERF_REQ_COUNT       RO  WRITE packets (role direction) since the last clear
//                0x090  PERF_REQ_FIRST       RO  PERF_CYCLES at the first byte of the first WRITE
//                0x094  PERF_REQ_LAST        RO  PERF_CYCLES at the first byte of the last WRITE
//                0x098  PERF_RSP_COUNT       RO  ACK/NAK packets (role direction) since the last clear
//                0x09C  PERF_RSP_FIRST       RO  PERF_CYCLES at the first byte of the first ACK/NAK
//                0x0A0  PERF_RSP_LAST        RO  PERF_CYCLES at the first byte of the last ACK/NAK
//                0x0A4  PERF_NAK_COUNT       RO  NAK packets among them
//                0x0A8  PERF_LAT_COUNT       RO  WRITE -> ACK/NAK pairs measured (the n-th ACK/NAK answers the n-th WRITE)
//                0x0AC  PERF_LAT_MIN         RO  minimum WRITE -> ACK/NAK time, in clock cycles (first byte to first byte)
//                0x0B0  PERF_LAT_MAX         RO  maximum
//                0x0B4  PERF_LAT_SUM_LO      RO  sum [31:0]
//                0x0B8  PERF_LAT_SUM_HI      RO  sum [63:32]
//                0x0C0  TX_CFG               RW  [N_QUEUE_PAIRS-1:0] TX data source of QP 256 + i (bit i): 0 data
//                                                generator (reset), 1 TX data source ports; change it only while the QP
//                                                has no transfer in progress (the source left out is held, not reset);
//                                                [8] TX buffer read back: the reads of the buffer window return the TX
//                                                buffer instead of the RX buffer (to check what was written)
//                0x0C4  TX_DESC_LOCAL        RW  descriptor: byte address of the payload in the TX buffer (multiple of 64)
//                0x0C8  TX_DESC_LEN          RW  descriptor: message length in bytes, multiple of 4 (4 to TXBUF_BYTES;
//                                                the upstream requester sends no pad: the last len % 4 bytes would be lost)
//                0x0CC  TX_DESC_REMOTE_LO    RW  descriptor: remote address [31:0], offset from the base VA of the QP
//                0x0D0  TX_DESC_REMOTE_HI    RW  descriptor: remote address [63:32]
//                0x0D4  TX_DESC_IMM          RW  descriptor: immediate data
//                0x0D8  TX_DESC_POST         WO  [23:0] local QPN, [24] RDMA WRITE with immediate: a write posts the
//                                                descriptor (TX_DESC_* above as they are; they keep their values)
//                0x0DC  TX_STATUS            RO  [7:0] free descriptor slots, [8] busy (descriptors or data inside the
//                                                data source), [18:16] last error: 1 QPN out of range, 2 QP on the data
//                                                generator, 3 length 0, not a multiple of 4 or outside the TX buffer,
//                                                4 TX buffer address
//                                                not a multiple of 64, 5 no free slot, 6 TX buffer read error
//                0x0E0  TX_POSTED            RO  descriptors accepted (errors 1 to 5: not accepted)
//                0x0E4  TX_CONSUMED          RO  messages whose payload has been read from the TX buffer (its area can
//                                                be written again)
//                0x0E8  TX_ERRORS            RO  descriptors refused and messages with a read error
//                                                (TX_*: cleared by the engine reset)
//                PERF monitor: it observes the frames at the MAC boundary (TX after the padding, RX from the MAC), so
//                on the requester it measures the round trip of each WRITE (network + remote responder) and on the
//                responder the time from a WRITE in to its ACK out; read it with the traffic stopped.
//                0x100  INJ_BUF[0..31]       RW  frame to inject: byte n of the frame (wire order) is byte (n % 4) of word (n / 4)
//                0x400  RESP[0..255]         RW  responder registers (QP context and MR tables, counters): register at byte
//                                                offset X of RoCE_ext_responder is at 0x400 + X; full-word writes only (wstrb ignored)
//                0x8000 RXBUF / TXBUF        RW  buffer window (one cycle more of read latency):
//                                                - read: RX buffer, byte address A of the responder AXI master is at
//                                                  0x8000 + A (TX buffer instead if TX_CFG[8] = 1);
//                                                - write: TX buffer, byte A of the buffer is at 0x8000 + A (wstrb
//                                                  honoured; the RX buffer is written only by the responder).
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
    // Number of queue pairs (power of two, at least 2, at most 8: one TX_CFG bit each)
    parameter int unsigned  N_QUEUE_PAIRS                    = 4,
    // Retransmission buffer size (2**N bytes)
    parameter int unsigned  RETRANSMISSION_ADDR_BUFFER_WIDTH = 21,
    // Responder: number of memory regions and RX buffer size in bytes (at most 32 KB, the CSR window)
    parameter int unsigned  N_MR                             = 16,
    parameter int unsigned  RXBUF_BYTES                      = 32768,
    // TX buffer size in bytes (at most 32 KB, the CSR window)
    parameter int unsigned  TXBUF_BYTES                      = 32768,

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
    localparam int unsigned CSR_ADDR_MSB = 8;  // registers and injector buffer (0x000 - 0x1FC)
    localparam int unsigned CSR_WIN_MSB  = 15; // 64 KB CSR window
    // CSR regions (address bits [15:9])
    localparam logic [6:0]  CSR_REGION_BASE  = 7'b0000000; // 0x0000 - 0x01FF registers, injector buffer
    localparam logic [5:0]  CSR_REGION_RESP  = 6'b000001;  // 0x0400 - 0x07FF responder registers (bits [15:10])

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
    localparam logic [6:0]  CSR_RXBUF_SIZE         = 7'h0A; // 0x028
    localparam logic [6:0]  CSR_TXBUF_SIZE         = 7'h0B; // 0x02C
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
    localparam logic [6:0]  CSR_PERF_CFG           = 7'h20; // 0x080
    localparam logic [6:0]  CSR_PERF_STATUS        = 7'h21; // 0x084
    localparam logic [6:0]  CSR_PERF_CYCLES        = 7'h22; // 0x088
    localparam logic [6:0]  CSR_PERF_REQ_COUNT     = 7'h23; // 0x08C
    localparam logic [6:0]  CSR_PERF_REQ_FIRST     = 7'h24; // 0x090
    localparam logic [6:0]  CSR_PERF_REQ_LAST      = 7'h25; // 0x094
    localparam logic [6:0]  CSR_PERF_RSP_COUNT     = 7'h26; // 0x098
    localparam logic [6:0]  CSR_PERF_RSP_FIRST     = 7'h27; // 0x09C
    localparam logic [6:0]  CSR_PERF_RSP_LAST      = 7'h28; // 0x0A0
    localparam logic [6:0]  CSR_PERF_NAK_COUNT     = 7'h29; // 0x0A4
    localparam logic [6:0]  CSR_PERF_LAT_COUNT     = 7'h2A; // 0x0A8
    localparam logic [6:0]  CSR_PERF_LAT_MIN       = 7'h2B; // 0x0AC
    localparam logic [6:0]  CSR_PERF_LAT_MAX       = 7'h2C; // 0x0B0
    localparam logic [6:0]  CSR_PERF_LAT_SUM_LO    = 7'h2D; // 0x0B4
    localparam logic [6:0]  CSR_PERF_LAT_SUM_HI    = 7'h2E; // 0x0B8
    localparam logic [6:0]  CSR_TX_CFG             = 7'h30; // 0x0C0
    localparam logic [6:0]  CSR_TX_DESC_LOCAL      = 7'h31; // 0x0C4
    localparam logic [6:0]  CSR_TX_DESC_LEN        = 7'h32; // 0x0C8
    localparam logic [6:0]  CSR_TX_DESC_REMOTE_LO  = 7'h33; // 0x0CC
    localparam logic [6:0]  CSR_TX_DESC_REMOTE_HI  = 7'h34; // 0x0D0
    localparam logic [6:0]  CSR_TX_DESC_IMM        = 7'h35; // 0x0D4
    localparam logic [6:0]  CSR_TX_DESC_POST       = 7'h36; // 0x0D8
    localparam logic [6:0]  CSR_TX_STATUS          = 7'h37; // 0x0DC
    localparam logic [6:0]  CSR_TX_POSTED          = 7'h38; // 0x0E0
    localparam logic [6:0]  CSR_TX_CONSUMED        = 7'h39; // 0x0E4
    localparam logic [6:0]  CSR_TX_ERRORS          = 7'h3A; // 0x0E8
    localparam logic [1:0]  CSR_INJ_BUF_PAGE       = 2'b10; // 0x100 - 0x17C, i.e. word indexes 7'h40 - 7'h5F

    // ID register value
    localparam logic [31:0] CSR_ID_VALUE = 32'h5244_4D41; // "RDMA"

    // CTRL and STATUS bit positions
    localparam int unsigned CTRL_CLEAR_ARP_BIT    = 0;
    localparam int unsigned CTRL_SPY_REQ_BIT      = 1;
    localparam int unsigned CTRL_INJECT_BIT       = 2;
    localparam int unsigned CTRL_ENGINE_RST_BIT   = 3;
    localparam int unsigned CTRL_RXBUF_CLEAR_BIT  = 4;
    localparam int unsigned CTRL_PERF_CLEAR_BIT   = 5;
    localparam int unsigned STATUS_SPY_VALID_BIT  = 0;
    localparam int unsigned STATUS_INJ_BUSY_BIT   = 1;
    localparam int unsigned STATUS_ENGINE_RST_BIT = 2;
    localparam int unsigned STATUS_RXBUF_BUSY_BIT = 3;
    localparam int unsigned TX_CFG_TXBUF_READ_BIT = 8;
    localparam int unsigned TX_POST_IMM_BIT       = 24;
    localparam int unsigned TX_STATUS_BUSY_BIT    = 8;
    localparam int unsigned TX_STATUS_ERR_LSB     = 16;

    // PERF monitor: WRITE packets that can wait for their ACK/NAK (power of two)
    localparam int unsigned PERF_FIFO_DEPTH       = 512;
    localparam int unsigned PERF_PEND_W           = $clog2(PERF_FIFO_DEPTH) + 1;

    // Engine reset from the CSR: length in clock cycles
    localparam int unsigned ENGINE_RST_CYCLES     = 16;
    localparam int unsigned ENGINE_RST_CNT_W      = $clog2(ENGINE_RST_CYCLES+1);

    // Responder AXI master toward the RX buffer
    localparam int unsigned RESP_AXI_ADDR_WIDTH   = 32;
    localparam int unsigned RESP_AXI_ID_WIDTH     = 4;

    // AXI4 read port of the TX buffer (toward the requester data source)
    localparam int unsigned TXBUF_AXI_ADDR_WIDTH  = 32;
    localparam int unsigned TXBUF_AXI_ID_WIDTH    = 4;

    // Requester data source: descriptors waiting (power of two), AXI bursts read ahead
    localparam int unsigned TX_DESC_FIFO_DEPTH    = 16;
    localparam int unsigned TX_READ_AHEAD         = 4;

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

    // Active-high resets: rst for the CSR, engine_rst for the engine, its streams and the RX buffer logic
    logic        rst;
    logic        engine_rst;
    logic        engine_rst_req_q;      // One-cycle pulse
    logic [ENGINE_RST_CNT_W-1:0] engine_rst_cnt_q;

    // AXI-lite handshakes
    logic        aw_w_ready_q;
    logic        write_en;
    logic [6:0]  write_idx;
    logic        write_inj_buf;
    logic        write_base;
    logic        write_resp;
    logic [31:0] write_old_value;
    logic [31:0] write_new_value;
    logic        ar_ready_q;
    logic        read_en;
    logic [6:0]  read_idx;
    logic        read_inj_buf;
    logic        read_base;
    logic        read_resp;
    logic        write_buf_win;         // buffer window (0x8000 - 0xFFFF): writes go to the TX buffer
    logic        read_buf_win;          // buffer window: reads come from the RX buffer, or the TX buffer (TX_CFG[8])
    logic        buf_rd_pending_q;      // buffer read: data one cycle after the address
    logic        buf_rd_tx_q;           // the pending buffer read is from the TX buffer
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

    // PERF monitor (wrapper)
    logic        perf_wrap_q;           // RX buffer wrap
    logic        perf_role_q;           // 0: requester, 1: responder
    logic        perf_clear_q;          // One-cycle pulse
    logic [31:0] perf_cycles;
    logic [31:0] perf_req_count;
    logic [31:0] perf_req_first;
    logic [31:0] perf_req_last;
    logic [31:0] perf_rsp_count;
    logic [31:0] perf_rsp_first;
    logic [31:0] perf_rsp_last;
    logic [31:0] perf_nak_count;
    logic [31:0] perf_lat_count;
    logic [31:0] perf_lat_min;
    logic [31:0] perf_lat_max;
    logic [63:0] perf_lat_sum;
    logic        perf_err_overflow;
    logic        perf_err_orphan;
    logic [PERF_PEND_W-1:0] perf_pending;

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

    // Responder registers
    logic        resp_cfg_wr_en;
    logic [31:0] resp_cfg_rd_data;

    // RX buffer
    logic        rxbuf_clear_q;         // One-cycle pulse
    logic        rxbuf_clear_busy;
    logic [31:0] rxbuf_rd_data;

    // TX buffer
    logic        tx_cfg_txbuf_read_q;   // TX_CFG[8]: reads of the buffer window from the TX buffer
    logic [N_QUEUE_PAIRS-1:0] tx_cfg_qp_src_q; // TX_CFG[N_QUEUE_PAIRS-1:0]: TX data source per QP (0 data generator)

    // Requester data source: descriptor registers, post pulse, status
    logic [31:0] tx_desc_local_q;
    logic [31:0] tx_desc_len_q;
    logic [63:0] tx_desc_remote_q;
    logic [31:0] tx_desc_imm_q;
    logic        tx_post_q;             // One-cycle pulse
    logic [23:0] tx_post_qpn_q;
    logic        tx_post_imm_q;
    logic [$clog2(TX_DESC_FIFO_DEPTH):0] tx_src_desc_free;
    logic        tx_src_busy;
    logic [31:0] tx_src_posted;
    logic [31:0] tx_src_consumed;
    logic [31:0] tx_src_errors;
    logic [2:0]  tx_src_last_error;

    // TX data source ports of the engine, one per QP (from RoCE_ext_tx_source). Element i is QP 256 + i: the arrays
    // are [N_QUEUE_PAIRS-1:0] like the engine ports (unpacked arrays connect from the left)
    logic        qp_wr_req_valid          [N_QUEUE_PAIRS-1:0];
    logic        qp_wr_req_ready          [N_QUEUE_PAIRS-1:0];
    logic        qp_wr_req_tx_type        [N_QUEUE_PAIRS-1:0];
    logic        qp_wr_req_is_immediate   [N_QUEUE_PAIRS-1:0];
    logic [31:0] qp_wr_req_immediate_data [N_QUEUE_PAIRS-1:0];
    logic [23:0] qp_wr_req_loc_qp         [N_QUEUE_PAIRS-1:0];
    logic [63:0] qp_wr_req_addr_offset    [N_QUEUE_PAIRS-1:0];
    logic [31:0] qp_wr_req_dma_length     [N_QUEUE_PAIRS-1:0];
    logic [QP_CH_DATA_WIDTH-1:0]   qp_axis_tdata [N_QUEUE_PAIRS-1:0];
    logic [QP_CH_DATA_WIDTH/8-1:0] qp_axis_tkeep [N_QUEUE_PAIRS-1:0];
    logic        qp_axis_tvalid           [N_QUEUE_PAIRS-1:0];
    logic        qp_axis_tready           [N_QUEUE_PAIRS-1:0];
    logic        qp_axis_tlast            [N_QUEUE_PAIRS-1:0];
    logic        qp_axis_tuser            [N_QUEUE_PAIRS-1:0];
    logic [31:0] txbuf_rd_data;

    // TX buffer AXI4 read port (slave), toward the requester data source
    logic [TXBUF_AXI_ID_WIDTH-1:0]   txbuf_axi_arid;
    logic [TXBUF_AXI_ADDR_WIDTH-1:0] txbuf_axi_araddr;
    logic [7:0]                      txbuf_axi_arlen;
    logic [2:0]                      txbuf_axi_arsize;
    logic [1:0]                      txbuf_axi_arburst;
    logic                            txbuf_axi_arvalid;
    logic                            txbuf_axi_arready;
    logic [TXBUF_AXI_ID_WIDTH-1:0]   txbuf_axi_rid;
    logic [MAC_DATA_WIDTH-1:0]       txbuf_axi_rdata;
    logic [1:0]                      txbuf_axi_rresp;
    logic                            txbuf_axi_rlast;
    logic                            txbuf_axi_rvalid;
    logic                            txbuf_axi_rready;

    // Responder AXI4 master (write channels) toward the RX buffer
    logic [RESP_AXI_ID_WIDTH-1:0]    resp_axi_awid;
    logic [RESP_AXI_ADDR_WIDTH-1:0]  resp_axi_awaddr;
    logic [7:0]                      resp_axi_awlen;
    logic [2:0]                      resp_axi_awsize;
    logic [1:0]                      resp_axi_awburst;
    logic                            resp_axi_awvalid;
    logic                            resp_axi_awready;
    logic [MAC_DATA_WIDTH-1:0]       resp_axi_wdata;
    logic [MAC_DATA_WIDTH/8-1:0]     resp_axi_wstrb;
    logic                            resp_axi_wlast;
    logic                            resp_axi_wvalid;
    logic                            resp_axi_wready;
    logic [RESP_AXI_ID_WIDTH-1:0]    resp_axi_bid;
    logic [1:0]                      resp_axi_bresp;
    logic                            resp_axi_bvalid;
    logic                            resp_axi_bready;

    // RW registers as seen on the bus
    logic [31:0] csr_mac_lo;
    logic [31:0] csr_mac_hi;
    logic [31:0] csr_ip;
    logic [31:0] csr_net_cfg;
    logic [31:0] csr_mon_qpn;
    logic [31:0] csr_mon_cfg;
    logic [31:0] csr_spy_qpn;
    logic [31:0] csr_perf_cfg;
    logic [31:0] csr_tx_cfg;

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

    // TX stream from the engine (before padding)
    logic [MAC_DATA_WIDTH   -1 : 0]  tx_engine_axis_tdata;
    logic [MAC_DATA_WIDTH/8 -1 : 0]  tx_engine_axis_tkeep;
    logic                            tx_engine_axis_tvalid;
    logic                            tx_engine_axis_tready;
    logic                            tx_engine_axis_tlast;
    logic                            tx_engine_axis_tuser;

    /////////////////////////
    //  Local assignments  //
    /////////////////////////

    assign rst         = ~rst_ni;
    assign engine_rst  = rst | (engine_rst_cnt_q != '0);

    assign csr_mac_lo  = ctrl_local_mac_q[31:0];
    assign csr_mac_hi  = {16'b0, ctrl_local_mac_q[47:32]};
    assign csr_ip      = ctrl_local_ip_q;
    assign csr_net_cfg = {9'b0, ctrl_prio_tag_q, 1'b0, ctrl_pmtu_q, ctrl_udp_port_q};
    assign csr_mon_qpn = {8'b0, mon_qpn_q};
    assign csr_mon_cfg = {19'b0, mon_thr_avg_po2_q, 4'b0, mon_lat_avg_po2_q};
    assign csr_spy_qpn = {8'b0, spy_qpn_q};
    assign csr_perf_cfg = {30'b0, perf_role_q, perf_wrap_q};
    assign csr_tx_cfg   = (32'(tx_cfg_txbuf_read_q) << TX_CFG_TXBUF_READ_BIT) | 32'(tx_cfg_qp_src_q);

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
    assign write_base = (s_ctrl_axilite_awaddr[CSR_WIN_MSB:CSR_ADDR_MSB+1] == CSR_REGION_BASE);
    assign write_resp = (s_ctrl_axilite_awaddr[CSR_WIN_MSB:CSR_ADDR_MSB+2] == CSR_REGION_RESP);
    assign write_inj_buf = write_base && (write_idx[6:5] == CSR_INJ_BUF_PAGE);
    assign write_buf_win = s_ctrl_axilite_awaddr[CSR_WIN_MSB];

    // Responder registers: full-word writes
    assign resp_cfg_wr_en = write_en && write_resp;

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
                CSR_PERF_CFG: write_old_value = csr_perf_cfg;
                CSR_TX_CFG  : write_old_value = csr_tx_cfg;
                CSR_TX_DESC_LOCAL     : write_old_value = tx_desc_local_q;
                CSR_TX_DESC_LEN       : write_old_value = tx_desc_len_q;
                CSR_TX_DESC_REMOTE_LO : write_old_value = tx_desc_remote_q[31:0];
                CSR_TX_DESC_REMOTE_HI : write_old_value = tx_desc_remote_q[63:32];
                CSR_TX_DESC_IMM       : write_old_value = tx_desc_imm_q;
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
            engine_rst_req_q  <= 1'b0;
            rxbuf_clear_q     <= 1'b0;
            perf_wrap_q       <= 1'b0;
            perf_role_q       <= 1'b0;
            perf_clear_q      <= 1'b0;
            tx_cfg_txbuf_read_q <= 1'b0;
            tx_cfg_qp_src_q   <= '0;
            tx_desc_local_q   <= '0;
            tx_desc_len_q     <= '0;
            tx_desc_remote_q  <= '0;
            tx_desc_imm_q     <= '0;
            tx_post_q         <= 1'b0;
            tx_post_qpn_q     <= '0;
            tx_post_imm_q     <= 1'b0;
            inj_len_q         <= '0;
            inj_start_q       <= 1'b0;
            for (int i = 0; i < INJ_BUF_WORDS; i++) inj_buf_q[i] <= '0;
        end
        else begin
            // Pulses last one cycle
            ctrl_clear_arp_q <= 1'b0;
            spy_req_q        <= 1'b0;
            inj_start_q      <= 1'b0;
            engine_rst_req_q <= 1'b0;
            rxbuf_clear_q    <= 1'b0;
            perf_clear_q     <= 1'b0;
            tx_post_q        <= 1'b0;

            if (write_en && write_base) begin
                if (write_inj_buf)
                    inj_buf_q[write_idx[4:0]] <= write_new_value;
                else begin
                    case (write_idx)
                        CSR_CTRL : begin
                            if (s_ctrl_axilite_wstrb[0]) begin
                                ctrl_clear_arp_q <= s_ctrl_axilite_wdata[CTRL_CLEAR_ARP_BIT];
                                spy_req_q        <= s_ctrl_axilite_wdata[CTRL_SPY_REQ_BIT];
                                inj_start_q      <= s_ctrl_axilite_wdata[CTRL_INJECT_BIT];
                                engine_rst_req_q <= s_ctrl_axilite_wdata[CTRL_ENGINE_RST_BIT];
                                rxbuf_clear_q    <= s_ctrl_axilite_wdata[CTRL_RXBUF_CLEAR_BIT];
                                perf_clear_q     <= s_ctrl_axilite_wdata[CTRL_PERF_CLEAR_BIT];
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
                        CSR_PERF_CFG: begin
                            perf_wrap_q <= write_new_value[0];
                            perf_role_q <= write_new_value[1];
                        end
                        CSR_TX_CFG  : begin
                            tx_cfg_qp_src_q     <= write_new_value[N_QUEUE_PAIRS-1:0];
                            tx_cfg_txbuf_read_q <= write_new_value[TX_CFG_TXBUF_READ_BIT];
                        end
                        CSR_TX_DESC_LOCAL     : tx_desc_local_q         <= write_new_value;
                        CSR_TX_DESC_LEN       : tx_desc_len_q           <= write_new_value;
                        CSR_TX_DESC_REMOTE_LO : tx_desc_remote_q[31:0]  <= write_new_value;
                        CSR_TX_DESC_REMOTE_HI : tx_desc_remote_q[63:32] <= write_new_value;
                        CSR_TX_DESC_IMM       : tx_desc_imm_q           <= write_new_value;
                        CSR_TX_DESC_POST      : begin
                            tx_post_q     <= 1'b1;
                            tx_post_qpn_q <= write_new_value[23:0];
                            tx_post_imm_q <= write_new_value[TX_POST_IMM_BIT];
                        end
                        default     : ; // Read-only or unmapped
                    endcase
                end
            end
        end
    end

    // Engine reset from the CSR (CTRL.ENGINE_RST): the engine, its streams and the RX buffer logic are held in reset
    // for ENGINE_RST_CYCLES; the CSR keep their values
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)
            engine_rst_cnt_q <= '0;
        else if (engine_rst_req_q)
            engine_rst_cnt_q <= ENGINE_RST_CNT_W'(ENGINE_RST_CYCLES);
        else if (engine_rst_cnt_q != '0)
            engine_rst_cnt_q <= engine_rst_cnt_q - 1'b1;
    end

    //////////////////////////
    //  AXI-lite read path  //
    //////////////////////////

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            ar_ready_q            <= 1'b0;
            s_ctrl_axilite_rvalid <= 1'b0;
            s_ctrl_axilite_rdata  <= '0;
            buf_rd_pending_q      <= 1'b0;
            buf_rd_tx_q           <= 1'b0;
        end
        else begin
            ar_ready_q <= s_ctrl_axilite_arvalid & ~ar_ready_q & ~s_ctrl_axilite_rvalid & ~buf_rd_pending_q;

            buf_rd_pending_q <= 1'b0;
            if (read_en && read_buf_win) begin
                // RX or TX buffer: the data comes one cycle later
                buf_rd_pending_q <= 1'b1;
                buf_rd_tx_q      <= tx_cfg_txbuf_read_q;
            end
            else if (buf_rd_pending_q) begin
                s_ctrl_axilite_rvalid <= 1'b1;
                s_ctrl_axilite_rdata  <= buf_rd_tx_q ? txbuf_rd_data : rxbuf_rd_data;
            end
            else if (read_en) begin
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
    assign read_base  = (s_ctrl_axilite_araddr[CSR_WIN_MSB:CSR_ADDR_MSB+1] == CSR_REGION_BASE);
    assign read_resp  = (s_ctrl_axilite_araddr[CSR_WIN_MSB:CSR_ADDR_MSB+2] == CSR_REGION_RESP);
    assign read_buf_win = s_ctrl_axilite_araddr[CSR_WIN_MSB];
    assign read_inj_buf = read_base && (read_idx[6:5] == CSR_INJ_BUF_PAGE);

    // Read multiplexer
    always_comb begin
        read_value = '0;
        if (read_resp)
            read_value = resp_cfg_rd_data;
        else if (read_inj_buf)
            read_value = inj_buf_q[read_idx[4:0]];
        else if (read_base) begin
            case (read_idx)
                CSR_ID                 : read_value = CSR_ID_VALUE;
                CSR_STATUS             : begin
                    read_value[STATUS_SPY_VALID_BIT] = spy_valid_q;
                    read_value[STATUS_INJ_BUSY_BIT]  = inj_busy_q;
                    read_value[STATUS_ENGINE_RST_BIT] = engine_rst;
                    read_value[STATUS_RXBUF_BUSY_BIT] = rxbuf_clear_busy;
                end
                CSR_INJ_LEN            : read_value = {24'b0, inj_len_q};
                CSR_MAC_LO             : read_value = csr_mac_lo;
                CSR_MAC_HI             : read_value = csr_mac_hi;
                CSR_IP                 : read_value = csr_ip;
                CSR_NET_CFG            : read_value = csr_net_cfg;
                CSR_MON_QPN            : read_value = csr_mon_qpn;
                CSR_MON_CFG            : read_value = csr_mon_cfg;
                CSR_RXBUF_SIZE         : read_value = 32'(RXBUF_BYTES);
                CSR_TXBUF_SIZE         : read_value = 32'(TXBUF_BYTES);
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
                CSR_PERF_CFG           : read_value = csr_perf_cfg;
                CSR_PERF_STATUS        : read_value = {6'b0, 10'(perf_pending), 14'b0, perf_err_orphan, perf_err_overflow};
                CSR_PERF_CYCLES        : read_value = perf_cycles;
                CSR_PERF_REQ_COUNT     : read_value = perf_req_count;
                CSR_PERF_REQ_FIRST     : read_value = perf_req_first;
                CSR_PERF_REQ_LAST      : read_value = perf_req_last;
                CSR_PERF_RSP_COUNT     : read_value = perf_rsp_count;
                CSR_PERF_RSP_FIRST     : read_value = perf_rsp_first;
                CSR_PERF_RSP_LAST      : read_value = perf_rsp_last;
                CSR_PERF_NAK_COUNT     : read_value = perf_nak_count;
                CSR_PERF_LAT_COUNT     : read_value = perf_lat_count;
                CSR_PERF_LAT_MIN       : read_value = perf_lat_min;
                CSR_PERF_LAT_MAX       : read_value = perf_lat_max;
                CSR_PERF_LAT_SUM_LO    : read_value = perf_lat_sum[31:0];
                CSR_PERF_LAT_SUM_HI    : read_value = perf_lat_sum[63:32];
                CSR_TX_CFG             : read_value = csr_tx_cfg;
                CSR_TX_DESC_LOCAL      : read_value = tx_desc_local_q;
                CSR_TX_DESC_LEN        : read_value = tx_desc_len_q;
                CSR_TX_DESC_REMOTE_LO  : read_value = tx_desc_remote_q[31:0];
                CSR_TX_DESC_REMOTE_HI  : read_value = tx_desc_remote_q[63:32];
                CSR_TX_DESC_IMM        : read_value = tx_desc_imm_q;
                CSR_TX_STATUS          : begin
                    read_value[7:0]                                   = 8'(tx_src_desc_free);
                    read_value[TX_STATUS_BUSY_BIT]                    = tx_src_busy;
                    read_value[TX_STATUS_ERR_LSB +: 3]                = tx_src_last_error;
                end
                CSR_TX_POSTED          : read_value = tx_src_posted;
                CSR_TX_CONSUMED        : read_value = tx_src_consumed;
                CSR_TX_ERRORS          : read_value = tx_src_errors;
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
        .rst            ( engine_rst           ),
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
        .rst            ( engine_rst                                 ),
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

    RoCE_ext_network_wrapper #(
        .MAC_DATA_WIDTH                     ( MAC_DATA_WIDTH                   ),
        .STACK_DATA_WIDTH                   ( MAC_DATA_WIDTH                   ),
        .QP_CH_DATA_WIDTH                   ( QP_CH_DATA_WIDTH                 ),
        .R0CE_ENG_CLK_PERIOD                ( ROCE_CLOCK_PERIOD_NS             ),
        .N_ROCE_TX_ENGINES                  ( N_ROCE_TX_ENGINES                ),
        .N_QUEUE_PAIRS                      ( N_QUEUE_PAIRS                    ),
        .RETRANSMISSION_ADDR_BUFFER_WIDTH   ( RETRANSMISSION_ADDR_BUFFER_WIDTH ),
        .ASYNC_MAC_STACK                    ( ASYNC_MAC_STACK                  ),
        .ENABLE_PFC                         ( ENABLE_PFC                       ),
        .DEBUG                              ( DEBUG                            ),
        .N_MR                               ( N_MR                             ),
        .AXI_ADDR_WIDTH                     ( RESP_AXI_ADDR_WIDTH              ),
        .AXI_ID_WIDTH                       ( RESP_AXI_ID_WIDTH                )
    ) roce_ext_network_wrapper_u (
        // Clocks and resets
        .clk_mac                    ( clk_i                 ),
        .rst_mac                    ( engine_rst            ),
        .clk_stack                  ( clk_i                 ),
        .rst_stack                  ( engine_rst            ),
        .clk_roce_eng               ( clk_i                 ),
        .rst_roce_eng               ( engine_rst            ),
        .flow_ctrl_pause            ( 1'b0                  ),

        // Ethernet AXI-Stream TX (toward the padding)
        .m_network_tx_axis_tdata    ( tx_engine_axis_tdata  ),
        .m_network_tx_axis_tkeep    ( tx_engine_axis_tkeep  ),
        .m_network_tx_axis_tvalid   ( tx_engine_axis_tvalid ),
        .m_network_tx_axis_tready   ( tx_engine_axis_tready ),
        .m_network_tx_axis_tlast    ( tx_engine_axis_tlast  ),
        .m_network_tx_axis_tuser    ( tx_engine_axis_tuser  ),

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
        .n_rnr_retransmit_triggers  ( mon_rnr_retransmit    ),

        // Responder registers
        .resp_cfg_wr_en             ( resp_cfg_wr_en                                  ),
        .resp_cfg_wr_addr           ( s_ctrl_axilite_awaddr[CSR_ADDR_MSB+1:CSR_ADDR_LSB] ),
        .resp_cfg_wr_data           ( s_ctrl_axilite_wdata                            ),
        .resp_cfg_rd_addr           ( s_ctrl_axilite_araddr[CSR_ADDR_MSB+1:CSR_ADDR_LSB] ),
        .resp_cfg_rd_data           ( resp_cfg_rd_data                                ),

        // Responder AXI4 master (write channels) toward the RX buffer
        .m_axi_awid                 ( resp_axi_awid         ),
        .m_axi_awaddr               ( resp_axi_awaddr       ),
        .m_axi_awlen                ( resp_axi_awlen        ),
        .m_axi_awsize               ( resp_axi_awsize       ),
        .m_axi_awburst              ( resp_axi_awburst      ),
        .m_axi_awlock               (                       ),
        .m_axi_awcache              (                       ),
        .m_axi_awprot               (                       ),
        .m_axi_awvalid              ( resp_axi_awvalid      ),
        .m_axi_awready              ( resp_axi_awready      ),
        .m_axi_wdata                ( resp_axi_wdata        ),
        .m_axi_wstrb                ( resp_axi_wstrb        ),
        .m_axi_wlast                ( resp_axi_wlast        ),
        .m_axi_wvalid               ( resp_axi_wvalid       ),
        .m_axi_wready               ( resp_axi_wready       ),
        .m_axi_bid                  ( resp_axi_bid          ),
        .m_axi_bresp                ( resp_axi_bresp        ),
        .m_axi_bvalid               ( resp_axi_bvalid       ),
        .m_axi_bready               ( resp_axi_bready       ),

        // TX data source of each QP: data generator or these ports (TX_CFG[N_QUEUE_PAIRS-1:0])
        .qp_src_sel                 ( tx_cfg_qp_src_q          ),
        .s_wr_req_valid             ( qp_wr_req_valid          ),
        .s_wr_req_ready             ( qp_wr_req_ready          ),
        .s_wr_req_tx_type           ( qp_wr_req_tx_type        ),
        .s_wr_req_is_immediate      ( qp_wr_req_is_immediate   ),
        .s_wr_req_immediate_data    ( qp_wr_req_immediate_data ),
        .s_wr_req_loc_qp            ( qp_wr_req_loc_qp         ),
        .s_wr_req_addr_offset       ( qp_wr_req_addr_offset    ),
        .s_wr_req_dma_length        ( qp_wr_req_dma_length     ),
        .s_qp_axis_tdata            ( qp_axis_tdata            ),
        .s_qp_axis_tkeep            ( qp_axis_tkeep            ),
        .s_qp_axis_tvalid           ( qp_axis_tvalid           ),
        .s_qp_axis_tready           ( qp_axis_tready           ),
        .s_qp_axis_tlast            ( qp_axis_tlast            ),
        .s_qp_axis_tuser            ( qp_axis_tuser            )
    );

    // Requester data source: descriptors from the CSR, payload from the TX buffer (AXI4 read), work requests and
    // payload to the QPs whose TX data source is the ports (TX_CFG)
    RoCE_ext_tx_source #(
        .AXI_DATA_WIDTH             ( MAC_DATA_WIDTH           ),
        .AXI_ADDR_WIDTH             ( TXBUF_AXI_ADDR_WIDTH     ),
        .AXI_ID_WIDTH               ( TXBUF_AXI_ID_WIDTH       ),
        .AXI_MAX_BURST_LEN          ( 16                       ),
        .QP_CH_DATA_WIDTH           ( QP_CH_DATA_WIDTH         ),
        .N_QP                       ( N_QUEUE_PAIRS            ),
        .BASE_QPN                   ( 256                      ),
        .SRC_BYTES                  ( TXBUF_BYTES              ),
        .DESC_FIFO_DEPTH            ( TX_DESC_FIFO_DEPTH       ),
        .READ_AHEAD                 ( TX_READ_AHEAD            ),
        .LEN_WIDTH                  ( $clog2(TXBUF_BYTES) + 1  ),
        .LEN_MULTIPLE               ( 4                        )
    ) tx_source_u (
        .clk                        ( clk_i                    ),
        .rst                        ( engine_rst               ),
        // Descriptor post (CSR)
        .s_post_valid               ( tx_post_q                ),
        .s_post_local_addr          ( tx_desc_local_q          ),
        .s_post_len                 ( tx_desc_len_q            ),
        .s_post_qpn                 ( tx_post_qpn_q            ),
        .s_post_remote_addr         ( tx_desc_remote_q         ),
        .s_post_imm_en              ( tx_post_imm_q            ),
        .s_post_imm_data            ( tx_desc_imm_q            ),
        .qp_src_sel                 ( tx_cfg_qp_src_q          ),
        // Status
        .desc_free                  ( tx_src_desc_free         ),
        .busy                       ( tx_src_busy              ),
        .stat_posted                ( tx_src_posted            ),
        .stat_consumed              ( tx_src_consumed          ),
        .stat_errors                ( tx_src_errors            ),
        .stat_last_error            ( tx_src_last_error        ),
        // AXI4 master (read channels) toward the TX buffer
        .m_axi_arid                 ( txbuf_axi_arid           ),
        .m_axi_araddr               ( txbuf_axi_araddr         ),
        .m_axi_arlen                ( txbuf_axi_arlen          ),
        .m_axi_arsize               ( txbuf_axi_arsize         ),
        .m_axi_arburst              ( txbuf_axi_arburst        ),
        .m_axi_arlock               (                          ),
        .m_axi_arcache              (                          ),
        .m_axi_arprot               (                          ),
        .m_axi_arvalid              ( txbuf_axi_arvalid        ),
        .m_axi_arready              ( txbuf_axi_arready        ),
        .m_axi_rid                  ( txbuf_axi_rid            ),
        .m_axi_rdata                ( txbuf_axi_rdata          ),
        .m_axi_rresp                ( txbuf_axi_rresp          ),
        .m_axi_rlast                ( txbuf_axi_rlast          ),
        .m_axi_rvalid               ( txbuf_axi_rvalid         ),
        .m_axi_rready               ( txbuf_axi_rready         ),
        // Work requests and payload, one port per QP
        .m_wr_req_valid             ( qp_wr_req_valid          ),
        .m_wr_req_ready             ( qp_wr_req_ready          ),
        .m_wr_req_tx_type           ( qp_wr_req_tx_type        ),
        .m_wr_req_is_immediate      ( qp_wr_req_is_immediate   ),
        .m_wr_req_immediate_data    ( qp_wr_req_immediate_data ),
        .m_wr_req_loc_qp            ( qp_wr_req_loc_qp         ),
        .m_wr_req_addr_offset       ( qp_wr_req_addr_offset    ),
        .m_wr_req_dma_length        ( qp_wr_req_dma_length     ),
        .m_axis_tdata               ( qp_axis_tdata            ),
        .m_axis_tkeep               ( qp_axis_tkeep            ),
        .m_axis_tvalid              ( qp_axis_tvalid           ),
        .m_axis_tready              ( qp_axis_tready           ),
        .m_axis_tlast               ( qp_axis_tlast            ),
        .m_axis_tuser               ( qp_axis_tuser            )
    );

    // RX buffer: written by the responder, read by the processor through the CSR (0x8000 + byte address)
    RoCE_ext_axi_bram #(
        .DATA_WIDTH     ( MAC_DATA_WIDTH        ),
        .ADDR_WIDTH     ( RESP_AXI_ADDR_WIDTH   ),
        .ID_WIDTH       ( RESP_AXI_ID_WIDTH     ),
        .MEM_BYTES      ( RXBUF_BYTES           )
    ) rx_buffer_u (
        .clk            ( clk_i                 ),
        .rst            ( engine_rst            ),
        // AXI4 slave (write channels)
        .s_axi_awid     ( resp_axi_awid         ),
        .s_axi_awaddr   ( perf_wrap_q ? (resp_axi_awaddr & RESP_AXI_ADDR_WIDTH'(RXBUF_BYTES - 1)) : resp_axi_awaddr ),
        .s_axi_awlen    ( resp_axi_awlen        ),
        .s_axi_awsize   ( resp_axi_awsize       ),
        .s_axi_awburst  ( resp_axi_awburst      ),
        .s_axi_awvalid  ( resp_axi_awvalid      ),
        .s_axi_awready  ( resp_axi_awready      ),
        .s_axi_wdata    ( resp_axi_wdata        ),
        .s_axi_wstrb    ( resp_axi_wstrb        ),
        .s_axi_wlast    ( resp_axi_wlast        ),
        .s_axi_wvalid   ( resp_axi_wvalid       ),
        .s_axi_wready   ( resp_axi_wready       ),
        .s_axi_bid      ( resp_axi_bid          ),
        .s_axi_bresp    ( resp_axi_bresp        ),
        .s_axi_bvalid   ( resp_axi_bvalid       ),
        .s_axi_bready   ( resp_axi_bready       ),
        // Read port (CSR)
        .rd_en          ( read_en && read_buf_win && !tx_cfg_txbuf_read_q ),
        .rd_addr        ( s_ctrl_axilite_araddr[CSR_WIN_MSB-1:CSR_ADDR_LSB] ),
        .rd_data        ( rxbuf_rd_data         ),
        // Clear
        .clear_start    ( rxbuf_clear_q         ),
        .clear_busy     ( rxbuf_clear_busy      )
    );

    // TX buffer: port A from the CSR (buffer window), port B AXI4 read from the requester data source
    RoCE_ext_tx_bram #(
        .DATA_WIDTH     ( MAC_DATA_WIDTH        ),
        .ADDR_WIDTH     ( TXBUF_AXI_ADDR_WIDTH  ),
        .ID_WIDTH       ( TXBUF_AXI_ID_WIDTH    ),
        .MEM_BYTES      ( TXBUF_BYTES           )
    ) tx_buffer_u (
        .clk            ( clk_i                 ),
        .rst            ( engine_rst            ),
        // Port A (CSR): writes of the buffer window, reads of the buffer window with TX_CFG[8] = 1
        .wr_en          ( write_en && write_buf_win ),
        .wr_addr        ( s_ctrl_axilite_awaddr[CSR_WIN_MSB-1:CSR_ADDR_LSB] ),
        .wr_data        ( s_ctrl_axilite_wdata  ),
        .wr_strb        ( s_ctrl_axilite_wstrb  ),
        .rd_en          ( read_en && read_buf_win && tx_cfg_txbuf_read_q ),
        .rd_addr        ( s_ctrl_axilite_araddr[CSR_WIN_MSB-1:CSR_ADDR_LSB] ),
        .rd_data        ( txbuf_rd_data         ),
        // Port B: AXI4 slave (read channels)
        .s_axi_arid     ( txbuf_axi_arid        ),
        .s_axi_araddr   ( txbuf_axi_araddr      ),
        .s_axi_arlen    ( txbuf_axi_arlen       ),
        .s_axi_arsize   ( txbuf_axi_arsize      ),
        .s_axi_arburst  ( txbuf_axi_arburst     ),
        .s_axi_arvalid  ( txbuf_axi_arvalid     ),
        .s_axi_arready  ( txbuf_axi_arready     ),
        .s_axi_rid      ( txbuf_axi_rid         ),
        .s_axi_rdata    ( txbuf_axi_rdata       ),
        .s_axi_rresp    ( txbuf_axi_rresp       ),
        .s_axi_rlast    ( txbuf_axi_rlast       ),
        .s_axi_rvalid   ( txbuf_axi_rvalid      ),
        .s_axi_rready   ( txbuf_axi_rready      )
    );

    // Pad the frames toward the MAC to 60 bytes (the CMAC adds the FCS but does not pad)
    cmac_pad #(
        .DATA_WIDTH     ( MAC_DATA_WIDTH        ),
        .KEEP_WIDTH     ( MAC_DATA_WIDTH/8      ),
        .USER_WIDTH     ( 1                     )
    ) tx_cmac_pad_u (
        .clk            ( clk_i                 ),
        .rst            ( engine_rst            ),
        // AXI input
        .s_axis_tdata   ( tx_engine_axis_tdata  ),
        .s_axis_tkeep   ( tx_engine_axis_tkeep  ),
        .s_axis_tvalid  ( tx_engine_axis_tvalid ),
        .s_axis_tready  ( tx_engine_axis_tready ),
        .s_axis_tlast   ( tx_engine_axis_tlast  ),
        .s_axis_tuser   ( tx_engine_axis_tuser  ),
        // AXI output
        .m_axis_tdata   ( m_eth_tx_axis_tdata   ),
        .m_axis_tkeep   ( m_eth_tx_axis_tkeep   ),
        .m_axis_tvalid  ( m_eth_tx_axis_tvalid  ),
        .m_axis_tready  ( m_eth_tx_axis_tready  ),
        .m_axis_tlast   ( m_eth_tx_axis_tlast   ),
        .m_axis_tuser   ( m_eth_tx_axis_tuser   )
    );

    // PERF monitor on the MAC side of the engine: TX after the padding (what enters the MAC), RX from the MAC
    rdma_perf_mon #(
        .DATA_WIDTH     ( MAC_DATA_WIDTH        ),
        .FIFO_DEPTH     ( PERF_FIFO_DEPTH       )
    ) perf_mon_u (
        .clk_i          ( clk_i                 ),
        .rst_i          ( rst                   ),
        .clear_i        ( perf_clear_q | engine_rst ),
        .role_i         ( perf_role_q           ),
        .udp_port_i     ( ctrl_udp_port_q       ),
        .tx_tdata_i     ( m_eth_tx_axis_tdata   ),
        .tx_beat_i      ( m_eth_tx_axis_tvalid & m_eth_tx_axis_tready ),
        .tx_tlast_i     ( m_eth_tx_axis_tlast   ),
        .rx_tdata_i     ( s_eth_rx_axis_tdata   ),
        .rx_beat_i      ( s_eth_rx_axis_tvalid & s_eth_rx_axis_tready ),
        .rx_tlast_i     ( s_eth_rx_axis_tlast   ),
        .cycles_o       ( perf_cycles           ),
        .req_count_o    ( perf_req_count        ),
        .req_first_o    ( perf_req_first        ),
        .req_last_o     ( perf_req_last         ),
        .rsp_count_o    ( perf_rsp_count        ),
        .rsp_first_o    ( perf_rsp_first        ),
        .rsp_last_o     ( perf_rsp_last         ),
        .nak_count_o    ( perf_nak_count        ),
        .lat_count_o    ( perf_lat_count        ),
        .lat_min_o      ( perf_lat_min          ),
        .lat_max_o      ( perf_lat_max          ),
        .lat_sum_o      ( perf_lat_sum          ),
        .err_overflow_o ( perf_err_overflow     ),
        .err_orphan_o   ( perf_err_orphan       ),
        .pending_o      ( perf_pending          )
    );

endmodule : custom_top_wrapper


// Description: PERF monitor of custom_top_wrapper. It observes the Ethernet frames on the two streams at the MAC
//              boundary (only their first beat, i.e. the first 64 bytes) and recognizes the RoCEv2 RDMA WRITE packets
//              (Ethernet II, IPv4 without options, UDP to the RoCE port, BTH opcode 0x06-0x0B) and the ACK/NAK packets
//              (BTH opcode 0x11, NAK when AETH syndrome[6:5] != 0).
//              With the role it picks the request stream (WRITE) and the response stream (ACK/NAK):
//                - requester (role 0): WRITE on TX, ACK/NAK on RX -> round trip of each WRITE;
//                - responder (role 1): WRITE on RX, ACK/NAK on TX -> time from a WRITE in to its ACK out.
//              Each WRITE pushes the cycle counter value at its first beat in a FIFO, each ACK/NAK pops it: the
//              difference (cycles between the first byte of the WRITE and the first byte of its ACK/NAK) is
//              accumulated in count, minimum, maximum and sum. Pairing in order assumes one ACK/NAK per WRITE, as
//              in RC with AckReq on every packet and no loss: a PSN gap (silent drops after the NAK) breaks it.
//              The two streams go through the same pipeline, so the latencies need no correction.
module rdma_perf_mon #(
    parameter int unsigned DATA_WIDTH = 512,
    parameter int unsigned FIFO_DEPTH = 512,  // WRITE waiting for their ACK/NAK (power of two)
    localparam int unsigned AW        = $clog2(FIFO_DEPTH)
) (
    input  logic                    clk_i,
    input  logic                    rst_i,        // synchronous, active high: everything, cycle counter included
    input  logic                    clear_i,      // synchronous, active high: statistics and stream state
    input  logic                    role_i,       // 0: requester, 1: responder
    input  logic [15:0]             udp_port_i,   // RoCE UDP port
    // TX stream toward the MAC (observed)
    input  logic [DATA_WIDTH-1:0]   tx_tdata_i,
    input  logic                    tx_beat_i,    // tvalid & tready
    input  logic                    tx_tlast_i,
    // RX stream from the MAC (observed)
    input  logic [DATA_WIDTH-1:0]   rx_tdata_i,
    input  logic                    rx_beat_i,    // tvalid & tready
    input  logic                    rx_tlast_i,
    // Results
    output logic [31:0]             cycles_o,
    output logic [31:0]             req_count_o,
    output logic [31:0]             req_first_o,
    output logic [31:0]             req_last_o,
    output logic [31:0]             rsp_count_o,
    output logic [31:0]             rsp_first_o,
    output logic [31:0]             rsp_last_o,
    output logic [31:0]             nak_count_o,
    output logic [31:0]             lat_count_o,
    output logic [31:0]             lat_min_o,
    output logic [31:0]             lat_max_o,
    output logic [63:0]             lat_sum_o,
    output logic                    err_overflow_o,
    output logic                    err_orphan_o,
    output logic [AW:0]             pending_o
);

    // Frame fields in the first beat (byte n of the frame is tdata[8n +: 8])
    localparam int unsigned B_ETH_TYPE = 12;  // 2 bytes
    localparam int unsigned B_IP_PROTO = 23;
    localparam int unsigned B_UDP_DST  = 36;  // 2 bytes
    localparam int unsigned B_BTH_OP   = 42;
    localparam int unsigned B_AETH_SYN = 54;

    // Free-running cycle counter
    logic [31:0] cycles_q;
    always_ff @(posedge clk_i) begin
        if (rst_i) cycles_q <= '0;
        else       cycles_q <= cycles_q + 1'b1;
    end
    assign cycles_o = cycles_q;

    // Stage 0: start of frame on each stream
    logic tx_sof_q, rx_sof_q;
    always_ff @(posedge clk_i) begin
        if (rst_i || clear_i) begin
            tx_sof_q <= 1'b1;
            rx_sof_q <= 1'b1;
        end
        else begin
            if (tx_beat_i) tx_sof_q <= tx_tlast_i;
            if (rx_beat_i) rx_sof_q <= rx_tlast_i;
        end
    end

    // Stage 1: fields of the first beat and its timestamp
    typedef struct packed {
        logic        first;
        logic [15:0] eth_type;
        logic [7:0]  ip_proto;
        logic [15:0] udp_dst;
        logic [7:0]  opcode;
        logic [7:0]  syndrome;
        logic [31:0] ts;
    } hdr_t;
    hdr_t tx_s1_q, rx_s1_q;

    function automatic hdr_t take_hdr(input logic beat_first, input logic [DATA_WIDTH-1:0] d, input logic [31:0] ts);
        hdr_t h;
        h.first    = beat_first;
        h.eth_type = {d[8*B_ETH_TYPE +: 8], d[8*(B_ETH_TYPE+1) +: 8]};
        h.ip_proto = d[8*B_IP_PROTO +: 8];
        h.udp_dst  = {d[8*B_UDP_DST +: 8], d[8*(B_UDP_DST+1) +: 8]};
        h.opcode   = d[8*B_BTH_OP +: 8];
        h.syndrome = d[8*B_AETH_SYN +: 8];
        h.ts       = ts;
        return h;
    endfunction

    always_ff @(posedge clk_i) begin
        if (rst_i || clear_i) begin
            tx_s1_q.first <= 1'b0;
            rx_s1_q.first <= 1'b0;
        end
        else begin
            tx_s1_q <= take_hdr(tx_beat_i && tx_sof_q, tx_tdata_i, cycles_q);
            rx_s1_q <= take_hdr(rx_beat_i && rx_sof_q, rx_tdata_i, cycles_q);
        end
    end

    // Stage 2: classification
    typedef struct packed {
        logic        write;
        logic        ack;     // ACK or NAK
        logic        nak;
        logic [31:0] ts;
    } cls_t;
    cls_t tx_s2_q, rx_s2_q;

    function automatic cls_t classify(input hdr_t h, input logic [15:0] port);
        cls_t c;
        logic roce;
        roce    = h.first && (h.eth_type == 16'h0800) && (h.ip_proto == 8'd17) && (h.udp_dst == port);
        c.write = roce && (h.opcode >= 8'h06) && (h.opcode <= 8'h0B);
        c.ack   = roce && (h.opcode == 8'h11);
        c.nak   = roce && (h.opcode == 8'h11) && (h.syndrome[6:5] != 2'b00);
        c.ts    = h.ts;
        return c;
    endfunction

    always_ff @(posedge clk_i) begin
        if (rst_i || clear_i) begin
            tx_s2_q <= '0;
            rx_s2_q <= '0;
        end
        else begin
            tx_s2_q <= classify(tx_s1_q, udp_port_i);
            rx_s2_q <= classify(rx_s1_q, udp_port_i);
        end
    end

    // Stage 3: request/response events by role, counters, timestamp FIFO
    logic        req_ev, rsp_ev, rsp_nak;
    logic [31:0] req_ts, rsp_ts;
    assign req_ev  = role_i ? rx_s2_q.write : tx_s2_q.write;
    assign req_ts  = role_i ? rx_s2_q.ts    : tx_s2_q.ts;
    assign rsp_ev  = role_i ? tx_s2_q.ack   : rx_s2_q.ack;
    assign rsp_nak = role_i ? tx_s2_q.nak   : rx_s2_q.nak;
    assign rsp_ts  = role_i ? tx_s2_q.ts    : rx_s2_q.ts;

    logic [31:0] fifo_mem [FIFO_DEPTH];
    logic [AW:0] wr_ptr_q, rd_ptr_q;
    logic        fifo_full, fifo_empty, push, pop;
    logic [31:0] fifo_rd_q;
    assign fifo_empty = (wr_ptr_q == rd_ptr_q);
    assign fifo_full  = (wr_ptr_q[AW] != rd_ptr_q[AW]) && (wr_ptr_q[AW-1:0] == rd_ptr_q[AW-1:0]);
    assign push       = req_ev && !fifo_full;
    assign pop        = rsp_ev && !fifo_empty;
    assign pending_o  = wr_ptr_q - rd_ptr_q;

    // Simple dual-port RAM, synchronous read (a WRITE and its ACK never fall in the same cycle)
    always_ff @(posedge clk_i) begin
        if (push) fifo_mem[wr_ptr_q[AW-1:0]] <= req_ts;
        if (pop)  fifo_rd_q <= fifo_mem[rd_ptr_q[AW-1:0]];
    end

    // Stage 4: latency of the popped pair; stage 5: statistics
    logic        s4_valid_q, s5_valid_q;
    logic [31:0] s4_rsp_ts_q, s5_lat_q;

    always_ff @(posedge clk_i) begin
        if (rst_i || clear_i) begin
            wr_ptr_q       <= '0;
            rd_ptr_q       <= '0;
            req_count_o    <= '0;
            req_first_o    <= '0;
            req_last_o     <= '0;
            rsp_count_o    <= '0;
            rsp_first_o    <= '0;
            rsp_last_o     <= '0;
            nak_count_o    <= '0;
            err_overflow_o <= 1'b0;
            err_orphan_o   <= 1'b0;
            s4_valid_q     <= 1'b0;
            s5_valid_q     <= 1'b0;
            lat_count_o    <= '0;
            lat_min_o      <= '1;
            lat_max_o      <= '0;
            lat_sum_o      <= '0;
        end
        else begin
            // Requests
            if (req_ev) begin
                req_count_o <= req_count_o + 1'b1;
                req_last_o  <= req_ts;
                if (req_count_o == '0) req_first_o <= req_ts;
                if (fifo_full) err_overflow_o <= 1'b1;
            end
            if (push) wr_ptr_q <= wr_ptr_q + 1'b1;

            // Responses
            if (rsp_ev) begin
                rsp_count_o <= rsp_count_o + 1'b1;
                rsp_last_o  <= rsp_ts;
                if (rsp_count_o == '0) rsp_first_o <= rsp_ts;
                if (rsp_nak) nak_count_o <= nak_count_o + 1'b1;
                if (fifo_empty) err_orphan_o <= 1'b1;
            end
            if (pop) rd_ptr_q <= rd_ptr_q + 1'b1;

            // Latency pipeline
            s4_valid_q  <= pop;
            s4_rsp_ts_q <= rsp_ts;
            s5_valid_q  <= s4_valid_q;
            s5_lat_q    <= s4_rsp_ts_q - fifo_rd_q;
            if (s5_valid_q) begin
                lat_count_o <= lat_count_o + 1'b1;
                lat_sum_o   <= lat_sum_o + 64'(s5_lat_q);
                if (s5_lat_q < lat_min_o) lat_min_o <= s5_lat_q;
                if (s5_lat_q > lat_max_o) lat_max_o <= s5_lat_q;
            end
        end
    end

endmodule : rdma_perf_mon
