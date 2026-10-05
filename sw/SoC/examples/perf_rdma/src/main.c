// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description:
//  Performance of the RDMA RoCEv2 engine between two boards (QSFP0 fiber), measured by the PERF monitor of
//  custom_rdma_rocev2: timestamps of the frames at the MAC boundary, in engine clock cycles (322.265625 MHz, 3.103 ns).
//  - Board B (ROLE=RX, run first): responder over the RX buffer in wrap mode (memory region of 64 KB over the 32 KB
//    buffer, the data are overwritten, no data check), PERF monitor in the responder role. It prints one report per
//    run of board A (a run ends after PERF_IDLE_MS without new WRITE): time from a WRITE in to its ACK out, rate.
//  - Board A (ROLE=TX): opens one QP toward board B and runs
//    1. latency: for each message size, PERF_LAT_REPS single RDMA WRITE, each one after the ACK of the previous one;
//       round trip of each packet (first byte of the WRITE into the MAC -> first byte of its ACK out of the MAC);
//    2. throughput, 1 QP: for each message size, PERF_THR_BYTES bytes of back-to-back RDMA WRITE: goodput (first
//       WRITE out -> last ACK in), message rate, Ethernet line rate of the WRITE frames, latency under load.
//  Message sizes from PERF_MIN_SIZE to PERF_MAX_SIZE (powers of 2). PMTU 4096 (engine default): one packet per message.
//  The start addresses are multiples of 64 bytes, as required by the responder (RESP_ALIGNED_WRITES = 1).
//  Link latency, one way (CMAC TX + fiber + CMAC RX): (round trip on A - WRITE in -> ACK out on B) / 2, same size.
//  Build with: make ROLE=TX (board A) or make ROLE=RX (board B). Run board B first, then board A; restart both to
//  repeat (both reset their engine at start).

#include "simplyv.h"
#include "rdma.h"
#include <stdint.h>

// CMAC Base Address
#define CMAC_BASEADDR   ((uintptr_t)_peripheral_CMAC_CSR_start)
// RDMA register offsets in rdma.h already include +0x10000.
#define RDMA_BASEADDR   ((uintptr_t)_peripheral_CMAC_CSR_start)

// Board A: sends the RDMA WRITE
#define BOARD_A_MAC     { 0x00, 0x0A, 0x35, 0xDE, 0xAD, 0x01 }
#define BOARD_A_IP      RDMA_IPV4(22, 1, 212, 10)
// Board B: receives the RDMA WRITE
#define BOARD_B_MAC     { 0x00, 0x0A, 0x35, 0xDE, 0xAD, 0x02 }
#define BOARD_B_IP      RDMA_IPV4(22, 1, 212, 11)

// Measurements
#define PERF_MIN_SIZE       64u         // bytes (multiple of 64)
#define PERF_MAX_SIZE       4096u       // bytes (at most the PMTU, 4096)
#define PERF_LAT_REPS       1000u       // single WRITE per size (latency)
#define PERF_THR_BYTES      (1u << 20)  // bytes per throughput run
#define PERF_GAP_MS         300u        // board A: pause between two runs (more than PERF_IDLE_MS)
#define PERF_IDLE_MS        100u        // board B: a run is over after this time without new WRITE
#define PERF_LAT_TIMEOUT_MS 10u         // board A: ACK of a single WRITE
#define PERF_THR_TIMEOUT_MS 2000u       // board A: ACK of a whole throughput run

// Responder of board B: memory region of 64 KB from offset 0 (the requester data generator wraps its offsets at
// 64 KB), on the 32 KB RX buffer in wrap mode; protection domain shared with the QP
#define RX_MR_INDEX         0u
#define RX_MR_KEY           0x5Au
#define RX_MR_BYTES         65536u
#define RX_PD               1u
// Remote QP and memory as seen by board A
#define PEER_QPN            RDMA_FIRST_QPN
#define PEER_R_KEY          RDMA_R_KEY(RX_MR_INDEX, RX_MR_KEY)
#define PEER_ADDR           0x0u
// QPN of board A (first QP opened after the engine reset), accepted by the responder of board B
#define BOARD_A_QPN         RDMA_FIRST_QPN

// Ethernet bytes of a WRITE ONLY frame on the wire besides the payload: Ethernet header 14, IPv4 20, UDP 8, BTH 12,
// RETH 16, ICRC 4, FCS 4, preamble/SFD 8, inter-frame gap 12
#define WRITE_WIRE_OVERHEAD 98u

// Busy wait (approximate, main clock at 100 MHz)
#define LOOPS_PER_MS        10000u
#define LINK_PRINT_MS       2000u
#define CYCLES_PER_MS       (RDMA_CLOCK_HZ / 1000u)

static void delay_ms(uint32_t ms)
{
  for (volatile uint32_t i = 0; i < ms * LOOPS_PER_MS; i++);
}

static void print_ip(uint32_t ip)
{
  printf("%u.%u.%u.%u", (unsigned)(ip >> 24), (unsigned)((ip >> 16) & 0xFF), (unsigned)((ip >> 8) & 0xFF), (unsigned)(ip & 0xFF));
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// 32-bit arithmetic helpers (no libgcc: 32 x 32 -> 64 multiply and 64 / 32 divide written out)
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static void umul32(uint32_t a, uint32_t b, uint32_t* hi, uint32_t* lo)
{
  uint32_t al = a & 0xFFFFu, ah = a >> 16, bl = b & 0xFFFFu, bh = b >> 16;
  uint32_t ll = al * bl, lh = al * bh, hl = ah * bl, hh = ah * bh;
  uint32_t mid = (ll >> 16) + (lh & 0xFFFFu) + (hl & 0xFFFFu);
  *lo = (ll & 0xFFFFu) | (mid << 16);
  *hi = hh + (lh >> 16) + (hl >> 16) + (mid >> 16);
}

// {hi, lo} / d, saturated to 0xFFFFFFFF when the quotient does not fit 32 bits
static uint32_t udiv64(uint32_t hi, uint32_t lo, uint32_t d)
{
  if (d == 0u || hi >= d) {
    return 0xFFFFFFFFu;
  }
  uint32_t q = 0;
  for (int i = 0; i < 32; i++) {
    uint32_t carry = hi >> 31;
    hi = (hi << 1) | (lo >> 31);
    lo <<= 1;
    q <<= 1;
    if (carry || hi >= d) {
      hi -= d;
      q |= 1u;
    }
  }
  return q;
}

// a * b / d
static uint32_t muldiv(uint32_t a, uint32_t b, uint32_t d)
{
  uint32_t hi, lo;
  umul32(a, b, &hi, &lo);
  return udiv64(hi, lo, d);
}

// Engine clock cycles to tenths of ns (1 cycle = 3.10303 ns)
static uint32_t cycles_to_ns10(uint32_t cycles)
{
  return muldiv(cycles, 310303u, 10000u);
}

// bits in cycles to Mbit/s (322.265625 = 5156.25 / 16)
static uint32_t rate_mbps(uint32_t bits, uint32_t cycles)
{
  return muldiv(bits, 5156u, cycles) >> 4;
}

// events in cycles to thousands per second
static uint32_t rate_k(uint32_t events, uint32_t cycles)
{
  return muldiv(events, RDMA_CLOCK_HZ / 1000u, cycles);
}

static void print_ns10(uint32_t ns10)
{
  printf("%6lu.%lu", (unsigned long)(ns10 / 10u), (unsigned long)(ns10 % 10u));
}

static void print_milli(uint32_t m) // 1234 -> "1.23"
{
  printf("%3lu.%02lu", (unsigned long)(m / 1000u), (unsigned long)((m % 1000u) / 10u));
}

// Latency columns: min / avg / max in ns
static void print_lat(const rdma_perf_t* p)
{
  uint32_t avg_ns10 = 0;
  if (p->lat_count != 0u) {
    if (p->lat_sum_hi == 0u && p->lat_count <= 400000u) {
      uint32_t hi, lo;
      umul32(p->lat_sum_lo, 310303u, &hi, &lo);
      avg_ns10 = udiv64(hi, lo, p->lat_count * 10000u);
    } else {
      avg_ns10 = cycles_to_ns10(udiv64(p->lat_sum_hi, p->lat_sum_lo, p->lat_count));
    }
  }
  print_ns10(cycles_to_ns10(p->lat_min));
  printf(" ");
  print_ns10(avg_ns10);
  printf(" ");
  print_ns10(cycles_to_ns10(p->lat_max));
}

// A run is valid when every WRITE has its ACK, without NAK and monitor errors
static int perf_valid(const rdma_perf_t* p, uint32_t packets)
{
  return (p->req_count == packets) && (p->rsp_count == packets) && (p->lat_count == packets) &&
         (p->nak_count == 0u) && ((p->status & (RDMA_PERF_STATUS_OVERFLOW | RDMA_PERF_STATUS_ORPHAN)) == 0u);
}

static void print_perf_raw(const rdma_perf_t* p)
{
  printf("    PERF: status 0x%08lx, %lu WRITE, %lu ACK/NAK, %lu NAK, %lu pairs\n\r", (unsigned long)p->status,
         (unsigned long)p->req_count, (unsigned long)p->rsp_count, (unsigned long)p->nak_count, (unsigned long)p->lat_count);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// CMAC
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Initialize the CMAC and wait for the link (RX aligned)
// NOTE: the link comes up only once the peer CMAC is initialized too (TX enabled, same RS-FEC setting),
//       so wait without timeout: board B is started first and waits here for board A
static void cmac_link_up()
{
  printf("Initializing the CMAC...\n\r");
  xlnx_cmac_init(CMAC_BASEADDR);

  uint32_t status = xlnx_cmac_rx_status(CMAC_BASEADDR);
  for (uint32_t ms = 0; (status & CMAC_STAT_RX_STATUS) == 0u; ms += 10) {
    if ((ms % LINK_PRINT_MS) == 0u) {
      printf("Waiting for the link, i.e. for the peer CMAC (STAT_RX_STATUS 0x%08lx)...\n\r", (unsigned long)status);
    }
    delay_ms(10);
    status = xlnx_cmac_rx_status(CMAC_BASEADDR);
  }
  printf("CMAC link up (STAT_RX_STATUS 0x%08lx)\n\r", (unsigned long)status);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Board A
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

static const rdma_node_t* tx_engine;
static const rdma_node_t* tx_peer;
static uint32_t tx_qpn;

// Start n RDMA WRITE of size bytes on the QP (data generator of the engine, back to back from PEER_ADDR)
static int tx_start(uint32_t size, uint32_t n)
{
  uint8_t frame[RDMA_CM_FRAME_BYTES];
  rdma_cm_req_t req = { 0 };
  req.req_type    = RDMA_CM_REQ_NULL;
  req.peer_qpn    = PEER_QPN;
  req.peer_r_key  = PEER_R_KEY;
  req.peer_addr   = PEER_ADDR;
  req.qpn         = tx_qpn;
  req.start       = 1;
  req.length      = size;
  req.n_transfers = n;
  size_t frame_size = rdma_cm_frame(frame, tx_engine, tx_peer, &req);
  return rdma_inject(RDMA_BASEADDR, frame, frame_size);
}

// Wait until the PERF monitor has seen count ACK/NAK, with a timeout in ms (engine clock)
static int tx_wait_rsp(uint32_t count, uint32_t timeout_ms)
{
  uint32_t t0 = rdma_perf_cycles(RDMA_BASEADDR);
  while (ioread32(RDMA_BASEADDR + RDMA_PERF_RSP_COUNT_REG) < count) {
    if ((rdma_perf_cycles(RDMA_BASEADDR) - t0) > timeout_ms * CYCLES_PER_MS) {
      return SIMPLYV_ERROR;
    }
  }
  return SIMPLYV_OK;
}

// Open the QP toward board B and find it in RTS
static int tx_open_qp()
{
  uint8_t frame[RDMA_CM_FRAME_BYTES];
  rdma_cm_req_t req = { 0 };
  rdma_qp_info_t qp;

  req.req_type   = RDMA_CM_REQ_OPEN_QP;
  req.peer_qpn   = PEER_QPN;
  req.peer_r_key = PEER_R_KEY;
  req.peer_addr  = PEER_ADDR;
  size_t frame_size = rdma_cm_frame(frame, tx_engine, tx_peer, &req);
  if (rdma_inject(RDMA_BASEADDR, frame, frame_size) != SIMPLYV_OK) {
    return SIMPLYV_ERROR;
  }
  delay_ms(1);

  for (uint32_t i = 0; i < RDMA_N_QUEUE_PAIRS; i++) {
    if ((rdma_qp_spy(RDMA_BASEADDR, RDMA_FIRST_QPN + i, &qp) == SIMPLYV_OK) && (qp.state == RDMA_QP_STATE_RTS) &&
        (qp.rem_qpn == PEER_QPN) && (qp.rem_ip == tx_peer->ip)) {
      tx_qpn = RDMA_FIRST_QPN + i;
      printf("QP %lu in RTS toward QP %lu of ", (unsigned long)tx_qpn, (unsigned long)qp.rem_qpn);
      print_ip(qp.rem_ip);
      printf(" (R_Key 0x%08lx, VA 0x%lx)\n\r", (unsigned long)PEER_R_KEY, (unsigned long)PEER_ADDR);
      return SIMPLYV_OK;
    }
  }
  return SIMPLYV_ERROR;
}

// 1. Latency: single WRITE, each one after the ACK of the previous one
static int tx_latency()
{
  rdma_perf_t p;
  printf("\n\r1. Latency: %lu single RDMA WRITE per size, round trip of each packet (WRITE into the MAC -> its ACK out of the MAC)\n\r",
         (unsigned long)PERF_LAT_REPS);
  printf("   size [B]   min [ns]   avg [ns]   max [ns]\n\r");
  for (uint32_t size = PERF_MIN_SIZE; size <= PERF_MAX_SIZE; size <<= 1) {
    uint32_t retx0 = ioread32(RDMA_BASEADDR + RDMA_MON_RETRANSMIT_REG);
    uint32_t done = 0;
    rdma_perf_clear(RDMA_BASEADDR);
    for (; done < PERF_LAT_REPS; done++) {
      if (tx_start(size, 1u) != SIMPLYV_OK || tx_wait_rsp(done + 1u, PERF_LAT_TIMEOUT_MS) != SIMPLYV_OK) {
        break;
      }
    }
    rdma_perf_read(RDMA_BASEADDR, &p);
    uint32_t retx = ioread32(RDMA_BASEADDR + RDMA_MON_RETRANSMIT_REG) - retx0;
    printf("   %8lu ", (unsigned long)size);
    print_lat(&p);
    if (done == PERF_LAT_REPS && perf_valid(&p, PERF_LAT_REPS) && retx == 0u) {
      printf("\n\r");
    } else {
      printf("   INVALID: %lu of %lu ACKed, %lu retransmission triggers\n\r", (unsigned long)done,
             (unsigned long)PERF_LAT_REPS, (unsigned long)retx);
      print_perf_raw(&p);
      return SIMPLYV_ERROR;
    }
    delay_ms(PERF_GAP_MS);
  }
  return SIMPLYV_OK;
}

// 2. Throughput, 1 QP: back-to-back WRITE
static int tx_throughput()
{
  rdma_perf_t p;
  printf("\n\r2. Throughput, 1 QP: %lu bytes of back-to-back RDMA WRITE per size\n\r", (unsigned long)PERF_THR_BYTES);
  printf("   goodput: RDMA payload from the first WRITE out to the last ACK in; line: Ethernet bytes of the WRITE frames\n\r");
  printf("   (+ preamble and inter-frame gap) from the first to the last WRITE out; latency: round trip under load\n\r");
  printf("   size [B]  messages  goodput [Gbit/s]  rate [Mmsg/s]  line [Gbit/s]   lat min [ns]   avg [ns]   max [ns]\n\r");
  for (uint32_t size = PERF_MIN_SIZE; size <= PERF_MAX_SIZE; size <<= 1) {
    uint32_t n = PERF_THR_BYTES / size;
    uint32_t retx0 = ioread32(RDMA_BASEADDR + RDMA_MON_RETRANSMIT_REG);
    rdma_perf_clear(RDMA_BASEADDR);
    int ok = (tx_start(size, n) == SIMPLYV_OK) && (tx_wait_rsp(n, PERF_THR_TIMEOUT_MS) == SIMPLYV_OK);
    rdma_perf_read(RDMA_BASEADDR, &p);
    uint32_t retx = ioread32(RDMA_BASEADDR + RDMA_MON_RETRANSMIT_REG) - retx0;
    uint32_t t_all = p.rsp_last - p.req_first;   // first WRITE out -> last ACK in
    uint32_t t_tx  = p.req_last - p.req_first;   // first -> last WRITE out (n - 1 frame intervals)
    printf("   %8lu  %8lu      ", (unsigned long)size, (unsigned long)n);
    print_milli(rate_mbps(n * size * 8u, t_all));
    printf("        ");
    print_milli(rate_k(n, t_all));
    printf("        ");
    // Line rate over n - 1 frame intervals
    print_milli((n > 1u && t_tx != 0u) ? muldiv(rate_mbps((size + WRITE_WIRE_OVERHEAD) * 8u, 1u), n - 1u, t_tx) : 0u);
    printf("     ");
    print_lat(&p);
    if (ok && perf_valid(&p, n) && retx == 0u) {
      printf("\n\r");
    } else {
      printf("   INVALID: %lu retransmission triggers\n\r", (unsigned long)retx);
      print_perf_raw(&p);
      return SIMPLYV_ERROR;
    }
    delay_ms(PERF_GAP_MS);
  }
  return SIMPLYV_OK;
}

static void rdma_tx_perf(const rdma_node_t* engine, const rdma_node_t* peer)
{
  tx_engine = engine;
  tx_peer   = peer;
  rdma_perf_config(RDMA_BASEADDR, 0u); // requester role

  printf("Opening a QP...\n\r");
  if (tx_open_qp() != SIMPLYV_OK) {
    printf("ERROR: no QP in RTS\n\r");
    return;
  }
  delay_ms(PERF_GAP_MS);

  if (tx_latency() == SIMPLYV_OK && tx_throughput() == SIMPLYV_OK) {
    printf("\n\rOK: all the runs completed, no NAK, no retransmission\n\r");
  } else {
    printf("\n\rERROR: run aborted (see above)\n\r");
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// Board B
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// Set up the responder (memory region of RX_MR_BYTES over the RX buffer in wrap mode, QP of board A)
static int rdma_rx_setup(const rdma_node_t* peer)
{
  rdma_mr_t mr = { .index = RX_MR_INDEX, .key = RX_MR_KEY, .pd = RX_PD, .perms = RDMA_MR_REMOTE_WRITE,
                   .base = 0, .length = RX_MR_BYTES };
  rdma_resp_qp_t qp = { .qpn = PEER_QPN, .rem_qpn = BOARD_A_QPN, .rem_ip = peer->ip, .start_psn = 0, .pd = RX_PD };

  if (rdma_rxbuf_clear(RDMA_BASEADDR) != SIMPLYV_OK) {
    printf("ERROR: RX buffer clear\n\r");
    return SIMPLYV_ERROR;
  }
  rdma_perf_config(RDMA_BASEADDR, RDMA_PERF_CFG_RXBUF_WRAP | RDMA_PERF_CFG_RESPONDER);
  if ((rdma_resp_mr(RDMA_BASEADDR, &mr) != SIMPLYV_OK) || (rdma_resp_qp(RDMA_BASEADDR, &qp) != SIMPLYV_OK)) {
    printf("ERROR: responder setup\n\r");
    return SIMPLYV_ERROR;
  }
  rdma_resp_enable(RDMA_BASEADDR, 1);
  rdma_perf_clear(RDMA_BASEADDR);

  printf("Responder: MR %lu (R_Key 0x%08lx) of %lu bytes over the RX buffer of %lu bytes in wrap mode, QP %lu <- QP %lu of ",
         (unsigned long)mr.index, (unsigned long)RDMA_R_KEY(mr.index, mr.key), (unsigned long)RX_MR_BYTES,
         (unsigned long)ioread32(RDMA_BASEADDR + RDMA_RXBUF_SIZE_REG), (unsigned long)qp.qpn, (unsigned long)qp.rem_qpn);
  print_ip(qp.rem_ip);
  printf("\n\r");
  return SIMPLYV_OK;
}

// One report per run of board A
static void rdma_rx_perf()
{
  rdma_perf_t p;
  rdma_resp_stats_t s0, s1;
  uint32_t run = 0;

  rdma_resp_stats(RDMA_BASEADDR, &s0);
  printf("Waiting for the runs of board A (WRITE in -> ACK out of each packet, at the MAC boundary)...\n\r");
  printf("   run  packets  size [B]   min [ns]   avg [ns]   max [ns]  goodput [Gbit/s]  rate [Mmsg/s]  NAK\n\r");
  while (1) {
    // Wait for a run: WRITE seen, then PERF_IDLE_MS without new WRITE
    uint32_t count = 0, t_change = rdma_perf_cycles(RDMA_BASEADDR);
    while (1) {
      uint32_t c = ioread32(RDMA_BASEADDR + RDMA_PERF_REQ_COUNT_REG);
      uint32_t now = rdma_perf_cycles(RDMA_BASEADDR);
      if (c != count) {
        count = c;
        t_change = now;
      } else if (count != 0u && (now - t_change) > PERF_IDLE_MS * CYCLES_PER_MS) {
        break;
      }
    }
    rdma_perf_read(RDMA_BASEADDR, &p);
    rdma_resp_stats(RDMA_BASEADDR, &s1);
    rdma_perf_clear(RDMA_BASEADDR);

    uint32_t pkts  = s1.write_pkts - s0.write_pkts;
    uint32_t bytes = s1.write_bytes - s0.write_bytes;
    uint32_t t_all = p.rsp_last - p.req_first;   // first WRITE in -> last ACK out
    run++;
    printf("   %3lu %8lu  %8lu ", (unsigned long)run, (unsigned long)p.req_count, (unsigned long)(pkts ? bytes / pkts : 0u));
    print_lat(&p);
    printf("      ");
    print_milli(bytes < (1u << 29) ? rate_mbps(bytes * 8u, t_all) : 0u);
    printf("        ");
    print_milli(rate_k(p.rsp_count, t_all));
    printf("   %3lu", (unsigned long)(s1.naks - s0.naks));
    if (!perf_valid(&p, p.req_count) || pkts != p.req_count) {
      printf("  INVALID (responder: %lu WRITE packets)\n\r", (unsigned long)pkts);
      print_perf_raw(&p);
    } else {
      printf("\n\r");
    }
    s0 = s1;
  }
}

int main()
{
  rdma_node_t board_a = { .mac = BOARD_A_MAC, .ip = BOARD_A_IP };
  rdma_node_t board_b = { .mac = BOARD_B_MAC, .ip = BOARD_B_IP };
#ifdef RDMA_ROLE_RX
  const rdma_node_t* local = &board_b;
#else
  const rdma_node_t* local = &board_a;
#endif

  // Initialize HAL
  simplyv_init();

#ifdef RDMA_ROLE_RX
  printf("RDMA RoCEv2 performance, board B (RX)\n\r");
#else
  printf("RDMA RoCEv2 performance, board A (TX)\n\r");
#endif

  // Check the RDMA engine
  uint32_t id = ioread32(RDMA_BASEADDR + RDMA_ID_REG);
  if (id != RDMA_ID) {
    printf("ERROR: RDMA ID 0x%08lx\n\r", (unsigned long)id);
    while (1);
  }

  // CMAC link
  cmac_link_up();

  // Engine reset (no QP open, responder tables empty, PERF monitor cleared), then the local addresses of the engine
  if (rdma_engine_reset(RDMA_BASEADDR) != SIMPLYV_OK) {
    printf("ERROR: engine reset\n\r");
    while (1);
  }
  rdma_config(RDMA_BASEADDR, local);
  printf("RDMA engine IP ");
  print_ip(local->ip);
  printf(", engine clock %lu Hz (PERF cycle 3.103 ns)\n\r", (unsigned long)RDMA_CLOCK_HZ);

#ifdef RDMA_ROLE_RX
  if (rdma_rx_setup(&board_a) == SIMPLYV_OK) {
    rdma_rx_perf();
  }
#else
  rdma_tx_perf(&board_a, &board_b);
#endif

  while (1);

  return 0;
}
