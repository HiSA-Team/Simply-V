// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description:
//  This file implements the functions to adoperate the RDMA RoCEv2 engine

#include "simplyv.h"
#include "rdma.h"

#define RDMA_POLL_TIMEOUT    100000u

static size_t put_be(uint8_t* buf, uint64_t value, size_t bytes)
{
    for (size_t i = 0; i < bytes; i++) {
        buf[i] = (uint8_t)(value >> (8u * (bytes - 1u - i)));
    }
    return bytes;
}

void rdma_config(uintptr_t baseaddr, const rdma_node_t* local)
{
    uint32_t mac_lo = ((uint32_t)local->mac[2] << 24) | ((uint32_t)local->mac[3] << 16) |
                      ((uint32_t)local->mac[4] << 8)  |  (uint32_t)local->mac[5];
    uint32_t mac_hi = ((uint32_t)local->mac[0] << 8)  |  (uint32_t)local->mac[1];

    iowrite32(baseaddr + RDMA_MAC_LO_REG, mac_lo);
    iowrite32(baseaddr + RDMA_MAC_HI_REG, mac_hi);
    iowrite32(baseaddr + RDMA_IP_REG, local->ip);
    iowrite32(baseaddr + RDMA_CTRL_REG, RDMA_CTRL_CLEAR_ARP);
}

size_t rdma_cm_frame(uint8_t* frame, const rdma_node_t* engine, const rdma_node_t* peer, const rdma_cm_req_t* req)
{
    size_t n = 0;
    uint32_t sum = 0;
    uint8_t qp_info_valid = (req->req_type != RDMA_CM_REQ_NULL) ? 1u : 0u;
    uint8_t txmeta_valid  = (req->req_type == RDMA_CM_REQ_NULL) ? 1u : 0u;

    // Ethernet header: from the peer to the engine
    for (size_t i = 0; i < 6; i++) frame[n++] = engine->mac[i];
    for (size_t i = 0; i < 6; i++) frame[n++] = peer->mac[i];
    n += put_be(&frame[n], 0x0800, 2);

    // IPv4 header (no options, don't fragment, TTL 64, UDP)
    size_t ip_start = n;
    n += put_be(&frame[n], 0x4500, 2);
    n += put_be(&frame[n], 20u + 8u + RDMA_CM_PAYLOAD_BYTES, 2);
    n += put_be(&frame[n], 0x0000, 2);
    n += put_be(&frame[n], 0x4000, 2);
    n += put_be(&frame[n], 0x4011, 2);
    n += put_be(&frame[n], 0x0000, 2);  // Checksum, computed below
    n += put_be(&frame[n], peer->ip, 4);
    n += put_be(&frame[n], engine->ip, 4);
    for (size_t i = ip_start; i < ip_start + 20u; i += 2) {
        sum += ((uint32_t)frame[i] << 8) | (uint32_t)frame[i + 1];
    }
    sum = (sum & 0xFFFFu) + (sum >> 16);
    sum = (sum & 0xFFFFu) + (sum >> 16);
    put_be(&frame[ip_start + 10u], (~sum) & 0xFFFFu, 2);

    // UDP header (no checksum): the CM requires the UDP length of a 64-byte payload
    n += put_be(&frame[n], RDMA_CM_REPLY_UDP_PORT, 2);
    n += put_be(&frame[n], RDMA_CM_UDP_PORT, 2);
    n += put_be(&frame[n], 8u + RDMA_CM_PAYLOAD_BYTES, 2);
    n += put_be(&frame[n], 0x0000, 2);

    // CM payload (big endian), "local" is the peer and "remote" is the engine
    frame[n++] = (uint8_t)((req->req_type << 1) | qp_info_valid);   //  0: {ack_type, ack_valid, req_type, qp_info_valid}
    n += put_be(&frame[n], req->peer_qpn & 0xFFFFFFu, 4);           //  1: local QPN
    n += put_be(&frame[n], 0, 4);                                   //  5: local PSN
    n += put_be(&frame[n], req->peer_r_key, 4);                     //  9: local r_key
    n += put_be(&frame[n], req->peer_addr, 8);                      // 13: local base address
    n += put_be(&frame[n], peer->ip, 4);                            // 21: local IP
    n += put_be(&frame[n], req->qpn & 0xFFFFFFu, 4);                // 25: remote QPN
    n += put_be(&frame[n], 0, 4);                                   // 29: remote PSN
    n += put_be(&frame[n], 0, 4);                                   // 33: remote r_key
    n += put_be(&frame[n], 0, 8);                                   // 37: remote base address
    n += put_be(&frame[n], engine->ip, 4);                          // 45: remote IP
    n += put_be(&frame[n], RDMA_CM_REPLY_UDP_PORT, 2);              // 49: listening port
    frame[n++] = (uint8_t)((1u << 3) | ((req->start ? 1u : 0u) << 1) | txmeta_valid); // 51: {WRITE, immediate, start, valid}
    n += put_be(&frame[n], req->length, 4);                         // 52: RDMA length
    n += put_be(&frame[n], req->n_transfers, 4);                    // 56: number of transfers
    n += put_be(&frame[n], 0, 4);                                   // 60: frequency (0: back to back)

    return n;
}

int rdma_inject(uintptr_t baseaddr, const uint8_t* frame, size_t size)
{
    if (frame == 0 || size == 0u || size > RDMA_INJ_BUF_BYTES) {
        return SIMPLYV_ERROR;
    }

    // Wait for a previous injection
    uint32_t timeout = RDMA_POLL_TIMEOUT;
    while ((ioread32(baseaddr + RDMA_STATUS_REG) & RDMA_STATUS_INJ_BUSY) && (timeout > 0u)) {
        timeout--;
    }
    if (timeout == 0u) {
        return SIMPLYV_ERROR;
    }

    // Byte n of the frame is byte (n % 4) of word (n / 4)
    for (size_t i = 0; i < size; i += 4) {
        uint32_t word = 0;
        for (size_t b = 0; (b < 4u) && (i + b < size); b++) {
            word |= ((uint32_t)frame[i + b]) << (8u * b);
        }
        iowrite32(baseaddr + RDMA_INJ_BUF + i, word);
    }
    iowrite32(baseaddr + RDMA_INJ_LEN_REG, (uint32_t)size);
    iowrite32(baseaddr + RDMA_CTRL_REG, RDMA_CTRL_INJECT);

    return SIMPLYV_OK;
}

int rdma_qp_spy(uintptr_t baseaddr, uint32_t qpn, rdma_qp_info_t* info)
{
    iowrite32(baseaddr + RDMA_SPY_QPN_REG, qpn);
    iowrite32(baseaddr + RDMA_CTRL_REG, RDMA_CTRL_QP_SPY);

    // Only the QPNs handled by the engine produce a snapshot
    uint32_t timeout = RDMA_POLL_TIMEOUT;
    while (((ioread32(baseaddr + RDMA_STATUS_REG) & RDMA_STATUS_SPY_VALID) == 0u) && (timeout > 0u)) {
        timeout--;
    }
    if (timeout == 0u) {
        return SIMPLYV_ERROR;
    }

    uint32_t state = ioread32(baseaddr + RDMA_SPY_STATE_REG);
    info->state         = state & 0x7u;
    info->syndrome      = (state >> 8) & 0xFFu;
    info->loc_qpn       = ioread32(baseaddr + RDMA_SPY_LOC_QPN_REG);
    info->rem_qpn       = ioread32(baseaddr + RDMA_SPY_REM_QPN_REG);
    info->loc_psn       = ioread32(baseaddr + RDMA_SPY_LOC_PSN_REG);
    info->rem_psn       = ioread32(baseaddr + RDMA_SPY_REM_PSN_REG);
    info->rem_acked_psn = ioread32(baseaddr + RDMA_SPY_REM_ACKED_PSN_REG);
    info->rem_ip        = ioread32(baseaddr + RDMA_SPY_REM_IP_REG);

    return SIMPLYV_OK;
}
