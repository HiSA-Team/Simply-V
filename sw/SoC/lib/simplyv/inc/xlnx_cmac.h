// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description:
//  This file defines the API to adoperate the CMAC subsystem

#ifndef XLNX_CMAC_H
#define XLNX_CMAC_H

#include <stdint.h>
#include <stddef.h>
#include "io.h"
#include "tinyIO.h"

// CMAC CSR offsets
#define CMAC_CSR_RSFEC_CONFIG_ENABLE                 0x0000107C
#define CMAC_CSR_RSFEC_CONFIG_INDICATION_CORRECTION  0x00001000
#define CMAC_CSR_CONFIGURATION_RX_REG1               0x00000014
#define CMAC_CSR_CONFIGURATION_TX_REG1               0x0000000C

// CMAC status and statistics CSR offsets (PG203)
#define CMAC_CSR_STAT_TX_STATUS                      0x00000200
#define CMAC_CSR_STAT_RX_STATUS                      0x00000204  // [0] stat_rx_status (link up), [1] stat_rx_aligned; latched, read twice
#define CMAC_CSR_TICK                                0x000002B0  // write 1 to latch the statistics counters (pm_tick is tied to 0)
// Statistics counters, 48 bits: LSB at the offset, MSB (bits [47:32]) at the offset + 4
#define CMAC_CSR_STAT_TX_TOTAL_PACKETS               0x00000500
#define CMAC_CSR_STAT_TX_TOTAL_GOOD_PACKETS          0x00000508
#define CMAC_CSR_STAT_TX_TOTAL_BYTES                 0x00000510
#define CMAC_CSR_STAT_RX_TOTAL_PACKETS               0x00000608
#define CMAC_CSR_STAT_RX_TOTAL_GOOD_PACKETS          0x00000610
#define CMAC_CSR_STAT_RX_TOTAL_BYTES                 0x00000618
#define CMAC_CSR_STAT_RX_PACKET_64_BYTES             0x00000628
#define CMAC_CSR_STAT_RX_PACKET_65_127_BYTES         0x00000630
#define CMAC_CSR_STAT_RX_PACKET_1024_1518_BYTES      0x00000650
#define CMAC_CSR_STAT_RX_BAD_FCS                     0x000006C0

// Fields of CMAC_CSR_STAT_RX_STATUS
#define CMAC_STAT_RX_STATUS                          0x1u
#define CMAC_STAT_RX_ALIGNED                         0x2u

// AXI-Stream FIFO CSR offsets
// NOTE: [RDMA setup] the AXI-Stream FIFO is replaced by the RDMA RoCEv2 engine in the CMAC subsystem,
//       whose CSR are now at this offset (see sw/SoC/examples/hello_rdma)
#define AXIS_FIFO_INTERRUPT_STATUS_REG               (0x00010000 + 0x0)
#define AXIS_FIFO_INTERRUPT_ENABLE_REG               (0x00010000 + 0x4)
#define AXIS_FIFO_TX_VACANCY_REG                     (0x00010000 + 0xC)
#define AXIS_FIFO_RX_OCCUPANCY_REG                   (0x00010000 + 0x1C)
#define AXIS_FIFO_RX_LEN_REG                         (0x00010000 + 0x24)
#define AXIS_FIFO_RX_DST_ADDR_REG                    (0x00010000 + 0x30)
#define AXIS_FIFO_TX_DST_ADDR_REG                    (0x00010000 + 0x2C)  // TDR
#define AXIS_FIFO_TX_LEN_REG  	                     (0x00010000 + 0x14)  // TLR
#define AXIS_FIFO_TX_DATA                            (0x0)
#define AXIS_FIFO_RX_DATA                            (0x1000)


void xlnx_cmac_init(uint32_t baseaddr);
uint32_t xlnx_cmac_rx_status(uint32_t baseaddr);
void xlnx_cmac_tick(uint32_t baseaddr);
uint64_t xlnx_cmac_read_stat(uint32_t baseaddr, uint32_t offset);
void xlnx_axis_fifo_init(uint32_t baseaddr);
size_t xlnx_rx_axis_fifo_data(uint32_t baseaddr, uint32_t data_baseaddr, uint8_t *rx_buf, size_t rx_buf_size);
size_t xlnx_tx_axis_fifo_data(uint32_t baseaddr, uint32_t data_baseaddr, const uint8_t *tx_buf, size_t tx_buf_size);

#endif // XLNX_CMAC_H
