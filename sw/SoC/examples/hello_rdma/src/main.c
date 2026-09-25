// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description:
//  Board-to-board test of the RDMA RoCEv2 engine in the CMAC subsystem (two boards connected through QSFP0).
//  - Board A (ROLE=TX, default): opens a QP and starts RDMA_N_TRANSFERS RDMA WRITE of RDMA_LENGTH bytes toward board B.
//    The CM requests are injected in the engine RX stream as if they came from board B.
//  - Board B (ROLE=RX): answers the ARP requests of board A and prints the CMAC RX statistics.
//  Build with: make ROLE=TX (board A) or make ROLE=RX (board B), and run board B first.
//  NOTE: board B does not acknowledge the RDMA WRITE (the engine has no RoCE responder), so board A retransmits
//        each packet up to 7 times (15000 cycles timeout) and then moves the QP to the ERROR state:
//        board B receives RDMA_N_TRANSFERS * 8 RoCE packets (1098 bytes each with RDMA_LENGTH = 1024).

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

// Transfers
#define RDMA_LENGTH         1024u
#define RDMA_N_TRANSFERS    2u
// Peer QP (arbitrary, board B has no QP)
#define PEER_QPN            0x11u
#define PEER_R_KEY          0x234u
#define PEER_ADDR           0x12341242u

// Busy wait (approximate, main clock at 100 MHz)
#define LOOPS_PER_MS        10000u
#define LINK_TIMEOUT_MS     5000u

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

// Initialize the CMAC and wait for the link (RX aligned)
static int cmac_link_up()
{
  printf("Initializing the CMAC...\n\r");
  xlnx_cmac_init(CMAC_BASEADDR);

  uint32_t status = 0;
  for (uint32_t ms = 0; ms < LINK_TIMEOUT_MS; ms += 10) {
    status = xlnx_cmac_rx_status(CMAC_BASEADDR);
    if (status & CMAC_STAT_RX_STATUS) {
      printf("CMAC link up (STAT_RX_STATUS 0x%08lx)\n\r", (unsigned long)status);
      return SIMPLYV_OK;
    }
    delay_ms(10);
  }
  printf("ERROR: CMAC link down (STAT_RX_STATUS 0x%08lx)\n\r", (unsigned long)status);
  return SIMPLYV_ERROR;
}

// Board A: open a QP, start the RDMA WRITE, close the QP
static void rdma_tx_test(const rdma_node_t* engine, const rdma_node_t* peer)
{
  uint8_t frame[RDMA_CM_FRAME_BYTES];
  size_t frame_size;
  rdma_cm_req_t req = { 0 };
  rdma_qp_info_t qp;
  uint32_t qpn = 0;

  req.peer_qpn   = PEER_QPN;
  req.peer_r_key = PEER_R_KEY;
  req.peer_addr  = PEER_ADDR;

  // Close the QPs left open by a previous run
  for (uint32_t i = 0; i < RDMA_N_QUEUE_PAIRS; i++) {
    if ((rdma_qp_spy(RDMA_BASEADDR, RDMA_FIRST_QPN + i, &qp) == SIMPLYV_OK) && (qp.state != RDMA_QP_STATE_RESET)) {
      printf("Closing QP %lu (state %lu)\n\r", (unsigned long)(RDMA_FIRST_QPN + i), (unsigned long)qp.state);
      req.req_type = RDMA_CM_REQ_CLOSE_QP;
      req.qpn      = RDMA_FIRST_QPN + i;
      frame_size = rdma_cm_frame(frame, engine, peer, &req);
      rdma_inject(RDMA_BASEADDR, frame, frame_size);
      delay_ms(1);
    }
  }

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

  // Wait for the transfers and the retransmissions
  delay_ms(100);
  printf("PSN difference (sent - acked): %lu\n\r", (unsigned long)ioread32(RDMA_BASEADDR + RDMA_MON_PSN_DIFF_REG));
  printf("Retransmission triggers:       %lu\n\r", (unsigned long)ioread32(RDMA_BASEADDR + RDMA_MON_RETRANSMIT_REG));
  if (rdma_qp_spy(RDMA_BASEADDR, qpn, &qp) == SIMPLYV_OK) {
    print_qp(&qp);
  }

  // CMAC TX statistics
  xlnx_cmac_tick(CMAC_BASEADDR);
  printf("CMAC TX: %lu packets, %lu bytes\n\r",
         (unsigned long)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_TX_TOTAL_PACKETS),
         (unsigned long)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_TX_TOTAL_BYTES));

  // Close the QP
  req.req_type = RDMA_CM_REQ_CLOSE_QP;
  req.start    = 0;
  frame_size = rdma_cm_frame(frame, engine, peer, &req);
  rdma_inject(RDMA_BASEADDR, frame, frame_size);
  printf("QP %lu closed\n\r", (unsigned long)qpn);
}

// Board B: print the CMAC statistics whenever they change
static void rdma_rx_monitor()
{
  uint32_t prev_packets = 0;
  uint32_t prev_tx_packets = 0;

  printf("Waiting RX frames...\n\r");
  while (1) {
    delay_ms(1000);
    // Latch the statistics counters
    xlnx_cmac_tick(CMAC_BASEADDR);
    uint32_t packets      = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_TOTAL_PACKETS);
    uint32_t good_packets = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_TOTAL_GOOD_PACKETS);
    uint32_t bytes        = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_TOTAL_BYTES);
    uint32_t small        = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_PACKET_64_BYTES) +
                            (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_PACKET_65_127_BYTES);
    uint32_t roce_packets = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_PACKET_1024_1518_BYTES);
    uint32_t bad_fcs      = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_RX_BAD_FCS);
    uint32_t tx_packets   = (uint32_t)xlnx_cmac_read_stat(CMAC_BASEADDR, CMAC_CSR_STAT_TX_TOTAL_PACKETS);
    if ((packets == prev_packets && tx_packets == prev_tx_packets) || (packets == 0u && tx_packets == 0u)) {
      prev_packets    = packets;
      prev_tx_packets = tx_packets;
      continue;
    }
    prev_packets    = packets;
    prev_tx_packets = tx_packets;
    printf("CMAC RX: %lu packets (%lu good, %lu bad FCS), %lu bytes, %lu of 64-127 bytes (ARP, CM), %lu of 1024-1518 bytes (RoCE) | TX: %lu packets\n\r",
           (unsigned long)packets, (unsigned long)good_packets, (unsigned long)bad_fcs, (unsigned long)bytes,
           (unsigned long)small, (unsigned long)roce_packets, (unsigned long)tx_packets);
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
  if (cmac_link_up() != SIMPLYV_OK) {
    while (1);
  }

  // Local addresses of the engine
  rdma_config(RDMA_BASEADDR, local);
  printf("RDMA engine IP ");
  print_ip(local->ip);
  printf("\n\r");

#ifdef RDMA_ROLE_RX
  rdma_rx_monitor();
#else
  rdma_tx_test(&board_a, &board_b);
#endif

  while (1);

  return 0;
}
