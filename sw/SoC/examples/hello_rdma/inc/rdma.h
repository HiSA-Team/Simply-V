// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description:
//  This file defines the API to adoperate the RDMA RoCEv2 engine (hw/units/custom_rdma_rocev2) in the CMAC subsystem.
//  The engine has no host interface: QPs are opened/started/closed through connection manager (CM) requests over UDP.
//  Here the CM requests are built in software and injected in the engine RX stream through the INJ_BUF CSR,
//  as if they came from the network (i.e. from the remote peer).

#ifndef RDMA_H
#define RDMA_H

#include <stdint.h>
#include <stddef.h>
#include "io.h"

// The RDMA CSR are in the CMAC subsystem, in place of the AXI-Stream FIFO CSR (CMAC CSR base + 0x10000)
#define RDMA_CSR_OFFSET                 0x00010000

// RDMA CSR offsets (see hw/units/custom_rdma_rocev2/custom_top_wrapper.sv)
#define RDMA_ID_REG                     (RDMA_CSR_OFFSET + 0x000)
#define RDMA_CTRL_REG                   (RDMA_CSR_OFFSET + 0x004)
#define RDMA_STATUS_REG                 (RDMA_CSR_OFFSET + 0x008)
#define RDMA_INJ_LEN_REG                (RDMA_CSR_OFFSET + 0x00C)
#define RDMA_MAC_LO_REG                 (RDMA_CSR_OFFSET + 0x010)
#define RDMA_MAC_HI_REG                 (RDMA_CSR_OFFSET + 0x014)
#define RDMA_IP_REG                     (RDMA_CSR_OFFSET + 0x018)
#define RDMA_NET_CFG_REG                (RDMA_CSR_OFFSET + 0x01C)
#define RDMA_MON_QPN_REG                (RDMA_CSR_OFFSET + 0x020)
#define RDMA_MON_CFG_REG                (RDMA_CSR_OFFSET + 0x024)
#define RDMA_MON_XFER_TIME_AVG_REG      (RDMA_CSR_OFFSET + 0x030)
#define RDMA_MON_XFER_TIME_MAVG_REG     (RDMA_CSR_OFFSET + 0x034)
#define RDMA_MON_LATENCY_AVG_REG        (RDMA_CSR_OFFSET + 0x038)
#define RDMA_MON_LATENCY_MAVG_REG       (RDMA_CSR_OFFSET + 0x03C)
#define RDMA_MON_PSN_DIFF_REG           (RDMA_CSR_OFFSET + 0x040)
#define RDMA_MON_RETRANSMIT_REG         (RDMA_CSR_OFFSET + 0x044)
#define RDMA_MON_RNR_RETRANSMIT_REG     (RDMA_CSR_OFFSET + 0x048)
#define RDMA_SPY_QPN_REG                (RDMA_CSR_OFFSET + 0x050)
#define RDMA_SPY_STATE_REG              (RDMA_CSR_OFFSET + 0x054)
#define RDMA_SPY_LOC_QPN_REG            (RDMA_CSR_OFFSET + 0x058)
#define RDMA_SPY_REM_QPN_REG            (RDMA_CSR_OFFSET + 0x05C)
#define RDMA_SPY_LOC_PSN_REG            (RDMA_CSR_OFFSET + 0x060)
#define RDMA_SPY_REM_PSN_REG            (RDMA_CSR_OFFSET + 0x064)
#define RDMA_SPY_REM_ACKED_PSN_REG      (RDMA_CSR_OFFSET + 0x068)
#define RDMA_SPY_R_KEY_REG              (RDMA_CSR_OFFSET + 0x06C)
#define RDMA_SPY_REM_ADDR_LO_REG        (RDMA_CSR_OFFSET + 0x070)
#define RDMA_SPY_REM_ADDR_HI_REG        (RDMA_CSR_OFFSET + 0x074)
#define RDMA_SPY_REM_IP_REG             (RDMA_CSR_OFFSET + 0x078)
#define RDMA_INJ_BUF                    (RDMA_CSR_OFFSET + 0x100)

// Register fields
#define RDMA_ID                         0x52444D41u  // "RDMA"
#define RDMA_CTRL_CLEAR_ARP             0x1u
#define RDMA_CTRL_QP_SPY                0x2u
#define RDMA_CTRL_INJECT                0x4u
#define RDMA_STATUS_SPY_VALID           0x1u
#define RDMA_STATUS_INJ_BUSY            0x2u
#define RDMA_INJ_BUF_BYTES              128u

// QP states (see RoCE_qp_state_module.sv)
#define RDMA_QP_STATE_RESET             0u
#define RDMA_QP_STATE_INIT              1u
#define RDMA_QP_STATE_RTS               3u
#define RDMA_QP_STATE_ERROR             6u

// QPs handled by the engine: RDMA_FIRST_QPN to RDMA_FIRST_QPN + RDMA_N_QUEUE_PAIRS - 1
#define RDMA_FIRST_QPN                  256u
#define RDMA_N_QUEUE_PAIRS              4u   // N_QUEUE_PAIRS of custom_top_wrapper

// Connection manager (see udp_RoCE_connection_manager*.sv and Scripts/send_connection_info.py upstream)
#define RDMA_CM_UDP_PORT                0x4321u  // UDP port of the engine CM
#define RDMA_CM_REPLY_UDP_PORT          0x4322u  // listening port in the requests, i.e. where the CM sends the replies
#define RDMA_CM_PAYLOAD_BYTES           64u
#define RDMA_CM_FRAME_BYTES             (14u + 20u + 8u + RDMA_CM_PAYLOAD_BYTES)
#define RDMA_CM_REQ_NULL                0u
#define RDMA_CM_REQ_OPEN_QP             1u   // NOTE: it also moves the QP to RTS (no need of REQ_MODIFY_QP_RTS)
#define RDMA_CM_REQ_MODIFY_QP_RTS       3u
#define RDMA_CM_REQ_CLOSE_QP            4u

// Build an IPv4 address, e.g. RDMA_IPV4(22, 1, 212, 10)
#define RDMA_IPV4(a, b, c, d)           ((((uint32_t)(a)) << 24) | (((uint32_t)(b)) << 16) | (((uint32_t)(c)) << 8) | ((uint32_t)(d)))

// Network node: the engine or its remote peer
typedef struct {
    uint8_t  mac[6];
    uint32_t ip;
} rdma_node_t;

// CM request, sent by the peer to the engine
typedef struct {
    uint8_t  req_type;      // RDMA_CM_REQ_*
    uint32_t peer_qpn;      // QPN of the peer
    uint32_t peer_r_key;    // Remote key of the peer memory
    uint64_t peer_addr;     // Base address of the peer memory
    uint32_t qpn;           // QPN of the engine (0 for REQ_OPEN_QP)
    uint8_t  start;         // TX meta: start the transfers (REQ_NULL only)
    uint32_t length;        // TX meta: RDMA WRITE length in bytes
    uint32_t n_transfers;   // TX meta: number of RDMA WRITE
} rdma_cm_req_t;

// QP context snapshot (QP spy)
typedef struct {
    uint32_t state;
    uint32_t syndrome;
    uint32_t loc_qpn;
    uint32_t rem_qpn;
    uint32_t loc_psn;
    uint32_t rem_psn;
    uint32_t rem_acked_psn;
    uint32_t rem_ip;
} rdma_qp_info_t;

// All the Functions returning int return SIMPLYV_ERROR in case of error and SIMPLYV_OK otherwise

// Set the local MAC and IPv4 addresses of the engine and clear its ARP cache
void rdma_config(uintptr_t baseaddr, const rdma_node_t* local);

// Build a CM request frame (Ethernet/IPv4/UDP) from the peer to the engine, return its length in bytes
size_t rdma_cm_frame(uint8_t* frame, const rdma_node_t* engine, const rdma_node_t* peer, const rdma_cm_req_t* req);

// Inject a frame (up to RDMA_INJ_BUF_BYTES) in the engine RX stream
int rdma_inject(uintptr_t baseaddr, const uint8_t* frame, size_t size);

// Take a snapshot of the context of an engine QP
int rdma_qp_spy(uintptr_t baseaddr, uint32_t qpn, rdma_qp_info_t* info);

#endif // RDMA_H
