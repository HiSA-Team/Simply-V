// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description:
//  This file defines the API to adoperate the CMAC subsystem

#ifndef XLNX_CMAC_H
#define XLNX_CMAC_H

#include <stdint.h>


extern const volatile uint32_t _peripheral_CMAC_CSR_start;
extern const volatile uint32_t _peripheral_m_acc_start;

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


#endif // XLNX_CMAC_H
