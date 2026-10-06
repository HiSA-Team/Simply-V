// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description:
//  This file defines the API to adoperate the RDMA RoCEv2 engine (hw/units/custom_rdma_rocev2) in the CMAC subsystem.
//  The engine has no host interface: QPs are opened/started/closed through connection manager (CM) requests over UDP.
//  Here the CM requests are built in software and injected in the engine RX stream through the INJ_BUF CSR,
//  as if they came from the network (i.e. from the remote peer).
//  The engine includes an RDMA WRITE responder (SimplyV_Custom_RDMA/ext): the WRITE received from the network are
//  checked against a QP table and a memory region (MR) table, written here at initialization, and stored in the RX
//  buffer (block RAM) of the unit, readable through the CSR.

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
#define RDMA_RXBUF_SIZE_REG             (RDMA_CSR_OFFSET + 0x028)
#define RDMA_TXBUF_SIZE_REG             (RDMA_CSR_OFFSET + 0x02C)
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
#define RDMA_PERF_CFG_REG               (RDMA_CSR_OFFSET + 0x080)
#define RDMA_PERF_STATUS_REG            (RDMA_CSR_OFFSET + 0x084)
#define RDMA_PERF_CYCLES_REG            (RDMA_CSR_OFFSET + 0x088)
#define RDMA_PERF_REQ_COUNT_REG         (RDMA_CSR_OFFSET + 0x08C)
#define RDMA_PERF_REQ_FIRST_REG         (RDMA_CSR_OFFSET + 0x090)
#define RDMA_PERF_REQ_LAST_REG          (RDMA_CSR_OFFSET + 0x094)
#define RDMA_PERF_RSP_COUNT_REG         (RDMA_CSR_OFFSET + 0x098)
#define RDMA_PERF_RSP_FIRST_REG         (RDMA_CSR_OFFSET + 0x09C)
#define RDMA_PERF_RSP_LAST_REG          (RDMA_CSR_OFFSET + 0x0A0)
#define RDMA_PERF_NAK_COUNT_REG         (RDMA_CSR_OFFSET + 0x0A4)
#define RDMA_PERF_LAT_COUNT_REG         (RDMA_CSR_OFFSET + 0x0A8)
#define RDMA_PERF_LAT_MIN_REG           (RDMA_CSR_OFFSET + 0x0AC)
#define RDMA_PERF_LAT_MAX_REG           (RDMA_CSR_OFFSET + 0x0B0)
#define RDMA_PERF_LAT_SUM_LO_REG        (RDMA_CSR_OFFSET + 0x0B4)
#define RDMA_PERF_LAT_SUM_HI_REG        (RDMA_CSR_OFFSET + 0x0B8)
#define RDMA_TX_CFG_REG                 (RDMA_CSR_OFFSET + 0x0C0)
#define RDMA_TX_DESC_LOCAL_REG          (RDMA_CSR_OFFSET + 0x0C4)   // descriptor: TX buffer byte offset
#define RDMA_TX_DESC_LEN_REG            (RDMA_CSR_OFFSET + 0x0C8)   // descriptor: length in bytes
#define RDMA_TX_DESC_REMOTE_LO_REG      (RDMA_CSR_OFFSET + 0x0CC)   // descriptor: remote address [31:0]
#define RDMA_TX_DESC_REMOTE_HI_REG      (RDMA_CSR_OFFSET + 0x0D0)   // descriptor: remote address [63:32]
#define RDMA_TX_DESC_IMM_REG            (RDMA_CSR_OFFSET + 0x0D4)   // descriptor: immediate data
#define RDMA_TX_DESC_POST_REG           (RDMA_CSR_OFFSET + 0x0D8)   // [23:0] QPN, [24] immediate: write = post
#define RDMA_TX_STATUS_REG              (RDMA_CSR_OFFSET + 0x0DC)
#define RDMA_TX_POSTED_REG              (RDMA_CSR_OFFSET + 0x0E0)
#define RDMA_TX_CONSUMED_REG            (RDMA_CSR_OFFSET + 0x0E4)
#define RDMA_TX_ERRORS_REG              (RDMA_CSR_OFFSET + 0x0E8)
#define RDMA_INJ_BUF                    (RDMA_CSR_OFFSET + 0x100)
#define RDMA_RESP_BASE                  (RDMA_CSR_OFFSET + 0x400)   // responder registers
#define RDMA_RXBUF_BASE                 (RDMA_CSR_OFFSET + 0x8000)  // RX buffer, read only (byte address A at + A)
#define RDMA_TXBUF_BASE                 (RDMA_CSR_OFFSET + 0x8000)  // TX buffer, same window: the writes go to the
                                                                    // TX buffer, the reads only with RDMA_TX_CFG_TXBUF_READ

// Responder registers (see SimplyV_Custom_RDMA/ext/rtl/RoCE_ext_responder.sv)
#define RDMA_RESP_CTRL_REG              (RDMA_RESP_BASE + 0x000)    // [0] enable
#define RDMA_RESP_INFO_REG              (RDMA_RESP_BASE + 0x004)    // [15:0] first QPN, [23:16] QPs, [31:24] MRs
#define RDMA_RESP_CNT_WRITE_PKTS_REG    (RDMA_RESP_BASE + 0x008)
#define RDMA_RESP_CNT_WRITE_BYTES_REG   (RDMA_RESP_BASE + 0x00C)
#define RDMA_RESP_CNT_ACK_REG           (RDMA_RESP_BASE + 0x010)
#define RDMA_RESP_CNT_NAK_REG           (RDMA_RESP_BASE + 0x014)
#define RDMA_RESP_CNT_DUP_REG           (RDMA_RESP_BASE + 0x018)
#define RDMA_RESP_CNT_DROP_REG          (RDMA_RESP_BASE + 0x01C)
#define RDMA_RESP_LAST_NAK_REG          (RDMA_RESP_BASE + 0x020)    // [31:24] syndrome, [23:0] PSN
#define RDMA_RESP_LAST_NAK_QPN_REG      (RDMA_RESP_BASE + 0x024)
#define RDMA_RESP_CNT_DMA_ERR_REG       (RDMA_RESP_BASE + 0x028)
// QP i (QPN RDMA_FIRST_QPN + i): RDMA_RESP_QP_REG(i, RDMA_RESP_QP_*)
#define RDMA_RESP_QP_REG(i, off)        (RDMA_RESP_BASE + 0x100 + 0x20 * (i) + (off))
#define RDMA_RESP_QP_CTRL               0x00   // [0] valid: writing 1 (re)initializes the QP, so write it last
#define RDMA_RESP_QP_REM_QPN            0x04
#define RDMA_RESP_QP_REM_IP             0x08
#define RDMA_RESP_QP_START_PSN          0x0C
#define RDMA_RESP_QP_PD                 0x10
#define RDMA_RESP_QP_EPSN               0x14   // read only: expected PSN
#define RDMA_RESP_QP_MSN                0x18   // read only: completed WRITE messages
#define RDMA_RESP_QP_IMM                0x1C   // read only: immediate data of the last WRITE with immediate
// MR j: RDMA_RESP_MR_REG(j, RDMA_RESP_MR_*)
#define RDMA_RESP_MR_REG(j, off)        (RDMA_RESP_BASE + 0x200 + 0x10 * (j) + (off))
#define RDMA_RESP_MR_CTRL               0x0    // [0] valid, [1] remote write, [2] remote read, [15:8] key, [23:16] PD
#define RDMA_RESP_MR_BASE_LO            0x4
#define RDMA_RESP_MR_BASE_HI            0x8
#define RDMA_RESP_MR_LEN                0xC

// Register fields
#define RDMA_ID                         0x52444D41u  // "RDMA"
#define RDMA_CTRL_CLEAR_ARP             0x1u
#define RDMA_CTRL_QP_SPY                0x2u
#define RDMA_CTRL_INJECT                0x4u
#define RDMA_STATUS_SPY_VALID           0x1u
#define RDMA_CTRL_ENGINE_RESET          0x8u
#define RDMA_CTRL_RXBUF_CLEAR           0x10u
#define RDMA_CTRL_PERF_CLEAR            0x20u
#define RDMA_STATUS_INJ_BUSY            0x2u
#define RDMA_STATUS_ENGINE_RESET        0x4u
#define RDMA_STATUS_RXBUF_BUSY          0x8u
#define RDMA_MR_VALID                   0x1u
#define RDMA_MR_REMOTE_WRITE            0x2u
#define RDMA_MR_REMOTE_READ             0x4u
#define RDMA_INJ_BUF_BYTES              128u
#define RDMA_PERF_CFG_RXBUF_WRAP        0x1u   // responder addresses modulo the RX buffer size
#define RDMA_PERF_CFG_RESPONDER         0x2u   // PERF role: responder (WRITE on RX, ACK on TX); 0: requester
#define RDMA_PERF_STATUS_OVERFLOW       0x1u
#define RDMA_PERF_STATUS_ORPHAN         0x2u
#define RDMA_TX_CFG_TXBUF_READ          0x100u // reads of the buffer window from the TX buffer (instead of RX)
#define RDMA_TX_CFG_QP_SRC(qpn)         (1u << ((qpn) - RDMA_FIRST_QPN)) // TX data source of a QP: 1 = ports
#define RDMA_TX_POST_IMM                0x01000000u // TX_DESC_POST: RDMA WRITE with immediate (TX_DESC_IMM)
#define RDMA_TX_STATUS_FREE(s)          ((s) & 0xFFu)          // free descriptor slots
#define RDMA_TX_STATUS_BUSY             0x100u                 // descriptors or payload inside the data source
#define RDMA_TX_STATUS_ERROR(s)         (((s) >> 16) & 0x7u)   // last error, RDMA_TX_ERR_*

// TX data source of a QP (TX_CFG[3:0])
#define RDMA_TX_SRC_GENERATOR           0u   // internal data generator, started by the CM START requests (reset)
#define RDMA_TX_SRC_PORTS               1u   // TX data source ports of the engine: messages posted with rdma_post_write()

// Last error of the TX data source (TX_STATUS[18:16]); errors 1 to 5: the descriptor is not posted
#define RDMA_TX_ERR_NONE                0u
#define RDMA_TX_ERR_QPN                 1u   // QPN outside the engine QPs
#define RDMA_TX_ERR_SOURCE              2u   // TX data source of the QP is the data generator
#define RDMA_TX_ERR_LENGTH              3u   // length 0, not a multiple of 4, or the message does not fit in the TX buffer
#define RDMA_TX_ERR_ALIGN               4u   // TX buffer offset not a multiple of RDMA_TXBUF_ALIGN
#define RDMA_TX_ERR_FULL                5u   // no free descriptor slot
#define RDMA_TX_ERR_READ                6u   // TX buffer read error (message sent anyway)

// Engine clock (CMAC user clock): one PERF cycle is 3.103 ns
#define RDMA_CLOCK_HZ                   322265625u

// QP states (see RoCE_qp_state_module.sv)
#define RDMA_QP_STATE_RESET             0u
#define RDMA_QP_STATE_INIT              1u
#define RDMA_QP_STATE_RTS               3u
#define RDMA_QP_STATE_ERROR             6u

// QPs handled by the engine: RDMA_FIRST_QPN to RDMA_FIRST_QPN + RDMA_N_QUEUE_PAIRS - 1
#define RDMA_FIRST_QPN                  256u
#define RDMA_N_QUEUE_PAIRS              4u   // N_QUEUE_PAIRS of custom_top_wrapper
#define RDMA_N_MR                       16u  // N_MR of custom_top_wrapper
#define RDMA_TXBUF_BYTES                32768u // TXBUF_BYTES of custom_top_wrapper
#define RDMA_TXBUF_ALIGN                64u  // TX buffer offset of a message: multiple of 64 bytes (one 512-bit beat)
#define RDMA_TX_DESC_SLOTS              16u  // descriptors that can wait in the TX data source
#define RDMA_TX_LEN_MULTIPLE            4u   // message length: multiple of 4 bytes (the upstream requester sends no pad)

// R_Key of a memory region: {MR index [31:8], key [7:0]}
#define RDMA_R_KEY(index, key)          ((((uint32_t)(index)) << 8) | (((uint32_t)(key)) & 0xFFu))

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

// Responder: memory region (RETH virtual address = offset from base, accepted if offset + length <= length)
typedef struct {
    uint32_t index;         // MR index, < RDMA_N_MR
    uint8_t  key;           // R_Key = RDMA_R_KEY(index, key)
    uint8_t  pd;            // protection domain
    uint32_t perms;         // RDMA_MR_REMOTE_WRITE | RDMA_MR_REMOTE_READ
    uint64_t base;          // address of the first byte (RX buffer: byte offset)
    uint32_t length;        // bytes
} rdma_mr_t;

// Responder: QP context written by software (the expected PSN and the MSN are kept by the hardware)
typedef struct {
    uint32_t qpn;           // local QPN, RDMA_FIRST_QPN to RDMA_FIRST_QPN + RDMA_N_QUEUE_PAIRS - 1
    uint32_t rem_qpn;       // QPN of the requester (destination QPN of the ACKs)
    uint32_t rem_ip;        // IPv4 address of the requester (the only source accepted)
    uint32_t start_psn;     // first PSN expected
    uint8_t  pd;            // protection domain
} rdma_resp_qp_t;

// Responder counters
typedef struct {
    uint32_t write_pkts;
    uint32_t write_bytes;
    uint32_t acks;
    uint32_t naks;
    uint32_t dups;
    uint32_t drops;
    uint32_t dma_errors;
    uint32_t last_nak;      // [31:24] syndrome, [23:0] PSN
    uint32_t last_nak_qpn;
} rdma_resp_stats_t;

// TX data source counters (cleared by the engine reset)
typedef struct {
    uint32_t posted;        // descriptors accepted
    uint32_t consumed;      // messages whose payload has been read from the TX buffer (area free again)
    uint32_t errors;        // descriptors refused and messages with a read error
    uint32_t free_slots;    // free descriptor slots
    uint32_t busy;          // 1: descriptors or payload still inside the data source
    uint32_t last_error;    // RDMA_TX_ERR_*
} rdma_tx_stats_t;

// PERF monitor snapshot (see custom_top_wrapper.sv: times in engine clock cycles, first byte to first byte)
typedef struct {
    uint32_t status;        // RDMA_PERF_STATUS_*, [25:16] WRITE waiting for their ACK
    uint32_t req_count;     // WRITE packets
    uint32_t req_first;     // cycle counter at the first WRITE
    uint32_t req_last;      // cycle counter at the last WRITE
    uint32_t rsp_count;     // ACK/NAK packets
    uint32_t rsp_first;
    uint32_t rsp_last;
    uint32_t nak_count;
    uint32_t lat_count;     // WRITE -> ACK/NAK pairs
    uint32_t lat_min;
    uint32_t lat_max;
    uint32_t lat_sum_lo;
    uint32_t lat_sum_hi;
} rdma_perf_t;

// All the Functions returning int return SIMPLYV_ERROR in case of error and SIMPLYV_OK otherwise

// Reset the engine (QPs, ARP cache, responder tables, RX/TX streams); the CSR (MAC, IP, ...) keep their values.
// Use it with the link idle.
int rdma_engine_reset(uintptr_t baseaddr);

// Write zeros in the whole RX buffer
int rdma_rxbuf_clear(uintptr_t baseaddr);

// Read a 32-bit word of the RX buffer (byte_offset multiple of 4)
uint32_t rdma_rxbuf_read(uintptr_t baseaddr, uint32_t byte_offset);

// Write a 32-bit word of the TX buffer (byte_offset multiple of 4)
void rdma_txbuf_write(uintptr_t baseaddr, uint32_t byte_offset, uint32_t value);

// Read back a 32-bit word of the TX buffer (byte_offset multiple of 4), to check what was written
uint32_t rdma_txbuf_read(uintptr_t baseaddr, uint32_t byte_offset);

// Select the TX data source of an engine QP: RDMA_TX_SRC_GENERATOR or RDMA_TX_SRC_PORTS.
// Change it only while the QP has no transfer in progress (the source left out is held, not reset).
int rdma_tx_source(uintptr_t baseaddr, uint32_t qpn, uint32_t source);

// Post an RDMA WRITE on an engine QP whose TX data source is RDMA_TX_SRC_PORTS: len bytes (multiple of
// RDMA_TX_LEN_MULTIPLE) of the TX buffer from byte offset local_off (multiple of RDMA_TXBUF_ALIGN) to the remote
// memory at remote_off, an offset from the base address the peer gave when the QP was opened. The messages leave in
// posting order. The TX buffer area of a message can be written again once TX_CONSUMED counts it (rdma_tx_stats,
// rdma_tx_wait_idle).
// SIMPLYV_ERROR: arguments out of range or no free descriptor slot (nothing posted).
int rdma_post_write(uintptr_t baseaddr, uint32_t qpn, uint32_t local_off, uint32_t len, uint64_t remote_off);

// Same, RDMA WRITE with immediate data
int rdma_post_write_imm(uintptr_t baseaddr, uint32_t qpn, uint32_t local_off, uint32_t len, uint64_t remote_off,
                        uint32_t imm);

// TX data source counters and status
void rdma_tx_stats(uintptr_t baseaddr, rdma_tx_stats_t* stats);

// Wait until every posted message has been read from the TX buffer; SIMPLYV_ERROR on timeout
int rdma_tx_wait_idle(uintptr_t baseaddr);

// Responder: register a memory region
int rdma_resp_mr(uintptr_t baseaddr, const rdma_mr_t* mr);

// Responder: set up a QP context
int rdma_resp_qp(uintptr_t baseaddr, const rdma_resp_qp_t* qp);

// Responder: enable (1) or disable (0); when disabled the WRITE requests are dropped by the upstream stack
void rdma_resp_enable(uintptr_t baseaddr, int enable);

// Responder: read the counters
void rdma_resp_stats(uintptr_t baseaddr, rdma_resp_stats_t* stats);

// Set the local MAC and IPv4 addresses of the engine and clear its ARP cache
void rdma_config(uintptr_t baseaddr, const rdma_node_t* local);

// Build a CM request frame (Ethernet/IPv4/UDP) from the peer to the engine, return its length in bytes
size_t rdma_cm_frame(uint8_t* frame, const rdma_node_t* engine, const rdma_node_t* peer, const rdma_cm_req_t* req);

// Inject a frame (up to RDMA_INJ_BUF_BYTES) in the engine RX stream
int rdma_inject(uintptr_t baseaddr, const uint8_t* frame, size_t size);

// Take a snapshot of the context of an engine QP
int rdma_qp_spy(uintptr_t baseaddr, uint32_t qpn, rdma_qp_info_t* info);

// PERF monitor: configuration (RDMA_PERF_CFG_*), clear, cycle counter, snapshot (read it with the traffic stopped)
void rdma_perf_config(uintptr_t baseaddr, uint32_t cfg);
void rdma_perf_clear(uintptr_t baseaddr);
uint32_t rdma_perf_cycles(uintptr_t baseaddr);
void rdma_perf_read(uintptr_t baseaddr, rdma_perf_t* perf);

#endif // RDMA_H
