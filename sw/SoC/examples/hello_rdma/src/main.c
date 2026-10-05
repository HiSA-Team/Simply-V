// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description:
//  Board-to-board test of the RDMA RoCEv2 engine in the CMAC subsystem (two boards connected through QSFP0).
//  - Board A (ROLE=TX, default): opens a QP toward the responder QP of board B (PEER_QPN, R_Key of its memory
//    region) and starts RDMA_N_TRANSFERS RDMA WRITE of RDMA_LENGTH bytes. The CM requests are injected in the engine
//    RX stream as if they came from board B.
//  - Board B (ROLE=RX): sets up its responder (memory region RX_MR_INDEX over the whole RX buffer, QP PEER_QPN
//    accepting the WRITE of board A), then prints the CMAC and responder statistics and checks the data received in
//    the RX buffer (data generator pattern: 32-bit words 0, 1, 2, ...).
//  Build with: make ROLE=TX (board A) or make ROLE=RX (board B). Run board B first, then board A; to repeat the
//  test, restart both (both reset their engine at start, so the first QP of board A is always QPN 256 and board B
//  expects PSN 0 again).
//  Expected with the default values: board B writes 2 packets (2048 bytes) into the RX buffer and sends 2 ACKs;
//  board A ends with the QP in RTS, acked PSN 1 and no retransmissions. On the wire: 2 RoCE packets of 1098 bytes
//  (1024-1518 bytes counter) from A to B and 2 ACKs of 62 bytes + FCS (65-127 bytes counter) from B to A, plus the
//  ARP frames and the CM replies of board A.

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

// Transfers. The responder of board B (RESP_ALIGNED_WRITES = 1, default) writes only payloads that start on a
// 64-byte boundary: PEER_ADDR must be a multiple of 64, and so must RDMA_LENGTH when RDMA_N_TRANSFERS > 1 (the
// data generator of board A writes the transfers back to back from PEER_ADDR); otherwise board B answers NAK 0x61.
#define RDMA_LENGTH         1024u
#define RDMA_N_TRANSFERS    2u
// Responder of board B: memory region over the whole RX buffer, protection domain shared with the QP
#define RX_MR_INDEX         0u
#define RX_MR_KEY           0x5Au
#define RX_PD               1u
// Remote QP and memory as seen by board A: responder QP of board B, R_Key of its memory region,
// virtual address = offset in the memory region
#define PEER_QPN            RDMA_FIRST_QPN
#define PEER_R_KEY          RDMA_R_KEY(RX_MR_INDEX, RX_MR_KEY)
#define PEER_ADDR           0x0u
// QPN of board A (first QP opened after the engine reset), accepted by the responder of board B
#define BOARD_A_QPN         RDMA_FIRST_QPN

// Busy wait (approximate, main clock at 100 MHz)
#define LOOPS_PER_MS        10000u
#define LINK_PRINT_MS       2000u

static void delay_ms(uint32_t ms)
{
  for (volatile uint32_t i = 0; i < ms * LOOPS_PER_MS; i++);
}

static void print_ip(uint32_t ip)
{
  printf("%u.%u.%u.%u", (unsigned)(ip >> 24), (unsigned)((ip >> 16) & 0xFF), (unsigned)((ip >> 8) & 0xFF), (unsigned)(ip & 0xFF));
}

static void print_qp(const rdma_qp_info_t* qp)
{
  printf("  QP %lu: state %lu, syndrome 0x%02lx, remote QPN 0x%lx, remote IP ", (unsigned long)qp->loc_qpn,
         (unsigned long)qp->state, (unsigned long)qp->syndrome, (unsigned long)qp->rem_qpn);
  print_ip(qp->rem_ip);
  printf(", local PSN %lu, remote PSN %lu, acked PSN %lu\n\r", (unsigned long)qp->loc_psn,
         (unsigned long)qp->rem_psn, (unsigned long)qp->rem_acked_psn);
}

// CMAC statistics, between two ticks
typedef struct {
  uint32_t tx_packets;
  uint32_t tx_good_packets;
  uint32_t tx_bytes;
  uint32_t tx_good_bytes;
  uint32_t tx_64;
  uint32_t tx_small;
  uint32_t tx_bad_fcs;
  uint32_t tx_frame_error;
  uint32_t rx_packets;
  uint32_t rx_good_packets;
  uint32_t rx_bytes;
  uint32_t rx_64;
  uint32_t rx_65_127;
  uint32_t rx_1024_1518;
  uint32_t rx_small;
  uint32_t rx_undersize;
  uint32_t rx_fragment;
  uint32_t rx_bad_fcs;
} cmac_stats_t;

// Latch the CMAC statistics and read them (only the 32 LSBs of the 48-bit counters)
static void cmac_read_stats(cmac_stats_t* s)
{
  xlnx_cmac_tick(CMAC_BASEADDR);
  s->tx_packets      = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_TX_TOTAL_PACKETS);
  s->tx_good_packets = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_TX_TOTAL_GOOD_PACKETS);
  s->tx_bytes        = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_TX_TOTAL_BYTES);
  s->tx_good_bytes   = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_TX_TOTAL_GOOD_BYTES);
  s->tx_64           = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_TX_PACKET_64_BYTES);
  s->tx_small        = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_TX_PACKET_SMALL);
  s->tx_bad_fcs      = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_TX_BAD_FCS);
  s->tx_frame_error  = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_TX_FRAME_ERROR);
  s->rx_packets      = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_TOTAL_PACKETS);
  s->rx_good_packets = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_TOTAL_GOOD_PACKETS);
  s->rx_bytes        = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_TOTAL_BYTES);
  s->rx_64           = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_PACKET_64_BYTES);
  s->rx_65_127       = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_PACKET_65_127_BYTES);
  s->rx_1024_1518    = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_PACKET_1024_1518_BYTES);
  s->rx_small        = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_PACKET_SMALL);
  s->rx_undersize    = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_UNDERSIZE);
  s->rx_fragment     = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_FRAGMENT);
  s->rx_bad_fcs      = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_BAD_FCS);
}

static int cmac_stats_empty(const cmac_stats_t* s)
{
  return (s->tx_packets == 0u) && (s->tx_small == 0u) && (s->rx_packets == 0u) && (s->rx_small == 0u) &&
         (s->rx_undersize == 0u) && (s->rx_fragment == 0u);
}

static void print_cmac_stats(const cmac_stats_t* s)
{
  printf("CMAC TX: %lu packets (%lu good, %lu of 64 bytes, %lu shorter than 64 bytes, %lu bad FCS, %lu frame errors), %lu bytes (%lu good)\n\r",
         (unsigned long)s->tx_packets, (unsigned long)s->tx_good_packets, (unsigned long)s->tx_64,
         (unsigned long)s->tx_small, (unsigned long)s->tx_bad_fcs, (unsigned long)s->tx_frame_error,
         (unsigned long)s->tx_bytes, (unsigned long)s->tx_good_bytes);
  printf("CMAC RX: %lu packets (%lu good, %lu of 64 bytes, %lu of 65-127 bytes, %lu of 1024-1518 bytes, %lu bad FCS), %lu bytes\n\r",
         (unsigned long)s->rx_packets, (unsigned long)s->rx_good_packets, (unsigned long)s->rx_64,
         (unsigned long)s->rx_65_127, (unsigned long)s->rx_1024_1518, (unsigned long)s->rx_bad_fcs,
         (unsigned long)s->rx_bytes);
  printf("CMAC RX shorter than 64 bytes: %lu (%lu undersize, %lu fragments)\n\r",
         (unsigned long)s->rx_small, (unsigned long)s->rx_undersize, (unsigned long)s->rx_fragment);
}

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

// Board A: open a QP, start the RDMA WRITE, close the QP
static void rdma_tx_test(const rdma_node_t* engine, const rdma_node_t* peer)
{
  uint8_t frame[RDMA_CM_FRAME_BYTES];
  size_t frame_size;
  rdma_cm_req_t req = { 0 };
  rdma_qp_info_t qp;
  cmac_stats_t stats;
  uint32_t qpn = 0;

  req.peer_qpn   = PEER_QPN;
  req.peer_r_key = PEER_R_KEY;
  req.peer_addr  = PEER_ADDR;

  // Latch the CMAC statistics once, to discard the frames of previous runs
  cmac_read_stats(&stats);

  // Open a QP (the engine moves it to RTS)
  printf("Opening a QP...\n\r");
  req.req_type = RDMA_CM_REQ_OPEN_QP;
  req.qpn      = 0;
  frame_size = rdma_cm_frame(frame, engine, peer, &req);
  if (rdma_inject(RDMA_BASEADDR, frame, frame_size) != SIMPLYV_OK) {
    printf("ERROR: injection failed\n\r");
    return;
  }
  delay_ms(1);

  // Look for the QP in RTS
  for (uint32_t i = 0; i < RDMA_N_QUEUE_PAIRS; i++) {
    if ((rdma_qp_spy(RDMA_BASEADDR, RDMA_FIRST_QPN + i, &qp) == SIMPLYV_OK) && (qp.state == RDMA_QP_STATE_RTS) &&
        (qp.rem_qpn == PEER_QPN) && (qp.rem_ip == peer->ip)) {
      qpn = RDMA_FIRST_QPN + i;
      print_qp(&qp);
      break;
    }
  }
  if (qpn == 0) {
    printf("ERROR: no QP in RTS\n\r");
    return;
  }

  // Start the RDMA WRITE
  printf("Starting %u RDMA WRITE of %u bytes on QP %lu...\n\r", RDMA_N_TRANSFERS, RDMA_LENGTH, (unsigned long)qpn);
  iowrite32(RDMA_BASEADDR + RDMA_MON_QPN_REG, qpn);
  req.req_type    = RDMA_CM_REQ_NULL;
  req.qpn         = qpn;
  req.start       = 1;
  req.length      = RDMA_LENGTH;
  req.n_transfers = RDMA_N_TRANSFERS;
  frame_size = rdma_cm_frame(frame, engine, peer, &req);
  rdma_inject(RDMA_BASEADDR, frame, frame_size);

  // Wait for the transfers and their ACKs
  delay_ms(100);
  uint32_t retransmissions = ioread32(RDMA_BASEADDR + RDMA_MON_RETRANSMIT_REG);
  printf("PSN difference (sent - acked): %lu\n\r", (unsigned long)ioread32(RDMA_BASEADDR + RDMA_MON_PSN_DIFF_REG));
  printf("Retransmission triggers:       %lu\n\r", (unsigned long)retransmissions);
  if (rdma_qp_spy(RDMA_BASEADDR, qpn, &qp) == SIMPLYV_OK) {
    print_qp(&qp);
    // One packet per RDMA WRITE (RDMA_LENGTH <= PMTU), PSNs from 0
    if ((qp.state == RDMA_QP_STATE_RTS) && (qp.rem_acked_psn == RDMA_N_TRANSFERS - 1u) && (retransmissions == 0u)) {
      printf("OK: all the RDMA WRITE acknowledged by board B, no retransmission\n\r");
    } else {
      printf("ERROR: expected QP in RTS, acked PSN %u and no retransmission\n\r", RDMA_N_TRANSFERS - 1u);
    }
  }

  // CMAC statistics of this run
  cmac_read_stats(&stats);
  print_cmac_stats(&stats);

  // Close the QP
  req.req_type = RDMA_CM_REQ_CLOSE_QP;
  req.start    = 0;
  frame_size = rdma_cm_frame(frame, engine, peer, &req);
  rdma_inject(RDMA_BASEADDR, frame, frame_size);
  printf("QP %lu closed\n\r", (unsigned long)qpn);
}

// Board B: set up the responder (memory region over the RX buffer, QP of board A)
static int rdma_rx_setup(const rdma_node_t* peer)
{
  uint32_t rxbuf_bytes = ioread32(RDMA_BASEADDR + RDMA_RXBUF_SIZE_REG);
  rdma_mr_t mr = { .index = RX_MR_INDEX, .key = RX_MR_KEY, .pd = RX_PD, .perms = RDMA_MR_REMOTE_WRITE,
                   .base = 0, .length = rxbuf_bytes };
  rdma_resp_qp_t qp = { .qpn = PEER_QPN, .rem_qpn = BOARD_A_QPN, .rem_ip = peer->ip, .start_psn = 0, .pd = RX_PD };

  if (rdma_rxbuf_clear(RDMA_BASEADDR) != SIMPLYV_OK) {
    printf("ERROR: RX buffer clear\n\r");
    return SIMPLYV_ERROR;
  }
  if ((rdma_resp_mr(RDMA_BASEADDR, &mr) != SIMPLYV_OK) || (rdma_resp_qp(RDMA_BASEADDR, &qp) != SIMPLYV_OK)) {
    printf("ERROR: responder setup\n\r");
    return SIMPLYV_ERROR;
  }
  rdma_resp_enable(RDMA_BASEADDR, 1);

  printf("Responder: MR %lu (R_Key 0x%08lx) over the RX buffer (%lu bytes), QP %lu <- QP %lu of ",
         (unsigned long)mr.index, (unsigned long)RDMA_R_KEY(mr.index, mr.key), (unsigned long)rxbuf_bytes,
         (unsigned long)qp.qpn, (unsigned long)qp.rem_qpn);
  print_ip(qp.rem_ip);
  printf("\n\r");
  return SIMPLYV_OK;
}

static void print_resp_stats(const rdma_resp_stats_t* s)
{
  printf("Responder: %lu WRITE packets (%lu bytes), %lu ACK, %lu NAK, %lu duplicates, %lu dropped, %lu memory errors\n\r",
         (unsigned long)s->write_pkts, (unsigned long)s->write_bytes, (unsigned long)s->acks, (unsigned long)s->naks,
         (unsigned long)s->dups, (unsigned long)s->drops, (unsigned long)s->dma_errors);
  if (s->naks != 0u) {
    printf("Responder: last NAK syndrome 0x%02lx, PSN %lu, QP %lu\n\r", (unsigned long)(s->last_nak >> 24),
           (unsigned long)(s->last_nak & 0xFFFFFFu), (unsigned long)s->last_nak_qpn);
  }
}

// Check the RX buffer: 32-bit words 0, 1, 2, ... (data generator of board A) over the bytes received
static void check_rx_buffer(uint32_t bytes)
{
  uint32_t errors = 0;
  for (uint32_t i = 0; i < bytes / 4u; i++) {
    uint32_t word = rdma_rxbuf_read(RDMA_BASEADDR, 4u * i);
    if (word != i) {
      if (errors < 4u) {
        printf("  RX buffer word %lu = 0x%08lx, expected 0x%08lx\n\r", (unsigned long)i, (unsigned long)word, (unsigned long)i);
      }
      errors++;
    }
  }
  if (errors == 0u) {
    printf("OK: RX buffer, %lu bytes as sent by board A\n\r", (unsigned long)bytes);
  } else {
    printf("ERROR: RX buffer, %lu wrong words out of %lu\n\r", (unsigned long)errors, (unsigned long)(bytes / 4u));
  }
}

// Board B: print the CMAC and responder statistics of each 1-second window with traffic, check the RX buffer
static void rdma_rx_monitor()
{
  cmac_stats_t stats;
  rdma_resp_stats_t resp;
  uint32_t total_rx_packets = 0;
  uint32_t total_rx_roce = 0;
  uint32_t total_tx_packets = 0;
  uint32_t checked_bytes = 0;

  // Latch the CMAC statistics once, to discard the frames of previous runs
  cmac_read_stats(&stats);

  printf("Waiting RX frames...\n\r");
  while (1) {
    delay_ms(1000);
    cmac_read_stats(&stats);
    if (cmac_stats_empty(&stats)) {
      continue;
    }
    total_rx_packets += stats.rx_packets;
    total_rx_roce    += stats.rx_1024_1518;
    total_tx_packets += stats.tx_packets;
    print_cmac_stats(&stats);
    printf("Total since start: RX %lu packets (%lu of 1024-1518 bytes), TX %lu packets\n\r",
           (unsigned long)total_rx_packets, (unsigned long)total_rx_roce, (unsigned long)total_tx_packets);
    rdma_resp_stats(RDMA_BASEADDR, &resp);
    print_resp_stats(&resp);
    if (resp.write_bytes != checked_bytes) {
      checked_bytes = resp.write_bytes;
      check_rx_buffer(checked_bytes);
    }
    printf("\n\r");
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
  printf("RDMA RoCEv2 test, board B (RX)\n\r");
#else
  printf("RDMA RoCEv2 test, board A (TX)\n\r");
#endif

  // Check the RDMA engine
  uint32_t id = ioread32(RDMA_BASEADDR + RDMA_ID_REG);
  if (id != RDMA_ID) {
    printf("ERROR: RDMA ID 0x%08lx\n\r", (unsigned long)id);
    while (1);
  }

  // CMAC link
  cmac_link_up();

  // Engine reset (no QP open, responder tables empty), then the local addresses of the engine
  if (rdma_engine_reset(RDMA_BASEADDR) != SIMPLYV_OK) {
    printf("ERROR: engine reset\n\r");
    while (1);
  }
  rdma_config(RDMA_BASEADDR, local);
  printf("RDMA engine IP ");
  print_ip(local->ip);
  printf("\n\r");

#ifdef RDMA_ROLE_RX
  if (rdma_rx_setup(&board_a) == SIMPLYV_OK) {
    rdma_rx_monitor();
  }
#else
  rdma_tx_test(&board_a, &board_b);
#endif

  while (1);

  return 0;
}
