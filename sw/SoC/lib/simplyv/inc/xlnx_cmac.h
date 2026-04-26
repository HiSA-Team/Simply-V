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

// AXI-Stream FIFO CSR offsets
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
void xlnx_axis_fifo_init(uint32_t baseaddr);
size_t xlnx_rx_axis_fifo_data(uint32_t baseaddr, uint32_t data_baseaddr, uint8_t *rx_buf, size_t rx_buf_size);
size_t xlnx_tx_axis_fifo_data(uint32_t baseaddr, uint32_t data_baseaddr, const uint8_t *tx_buf, size_t tx_buf_size);

#endif // XLNX_CMAC_H
