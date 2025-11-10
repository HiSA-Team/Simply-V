/******************************************************************************
* Simplified & adapted for UninaSoC / Baremetal RISC-V
* Original Copyright (C) Xilinx, Inc. / AMD
*
* SPDX-License-Identifier: MIT
******************************************************************************/

#ifndef XAXICDMA_HW_H_
#define XAXICDMA_HW_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include "io.h"  // provides ioread32() / iowrite32()

/************************** Constant Definitions *****************************/

#define XAXICDMA_BD_MINIMUM_ALIGNMENT 0x40  /**< Descriptor alignment requirement */

/* Register Offsets */
#define XAXICDMA_CR_OFFSET          0x0000  /**< Control register */
#define XAXICDMA_SR_OFFSET          0x0004  /**< Status register */
#define XAXICDMA_CDESC_OFFSET       0x0008  /**< Current descriptor pointer */
#define XAXICDMA_TDESC_OFFSET       0x0010  /**< Tail descriptor pointer */
#define XAXICDMA_SRCADDR_OFFSET     0x0018  /**< Source address register */
#define XAXICDMA_DSTADDR_OFFSET     0x0020  /**< Destination address register */
#define XAXICDMA_BTT_OFFSET         0x0028  /**< Bytes to transfer */

/* Control Register Bits */
#define XAXICDMA_CR_RESET_MASK      0x00000004  /**< Reset DMA engine */
#define XAXICDMA_CR_SGMODE_MASK     0x00000008  /**< Scatter-gather mode */
#define XAXICDMA_CR_KHOLE_RD_MASK   0x00000010  /**< Keyhole Read */
#define XAXICDMA_CR_KHOLE_WR_MASK   0x00000020  /**< Keyhole Write */

/* Status Register Bits */
#define XAXICDMA_SR_IDLE_MASK         0x00000002  /**< DMA channel idle */
#define XAXICDMA_SR_SGINCLD_MASK      0x00000008  /**< Hybrid build */
#define XAXICDMA_SR_ERR_INTERNAL_MASK 0x00000010  /**< Datamover internal error */
#define XAXICDMA_SR_ERR_SLAVE_MASK    0x00000020  /**< Datamover slave error */
#define XAXICDMA_SR_ERR_DECODE_MASK   0x00000040  /**< Datamover decode error */
#define XAXICDMA_SR_ERR_ALL_MASK      0x00000070  /**< All Datamover errors */

/* Interrupt Masks */
#define XAXICDMA_XR_IRQ_IOC_MASK      0x00001000  /**< Completion interrupt */
#define XAXICDMA_XR_IRQ_DELAY_MASK    0x00002000  /**< Delay interrupt */
#define XAXICDMA_XR_IRQ_ERROR_MASK    0x00004000  /**< Error interrupt */
#define XAXICDMA_XR_IRQ_ALL_MASK      0x00007000  /**< All interrupts */

/* Delay/Coalescing counters */
#define XAXICDMA_XR_DELAY_MASK    0xFF000000
#define XAXICDMA_XR_COALESCE_MASK 0x00FF0000
#define XAXICDMA_DELAY_SHIFT      24
#define XAXICDMA_COALESCE_SHIFT   16

#define XAXICDMA_DELAY_MAX        0xFF
#define XAXICDMA_COALESCE_MAX     0xFF

/* Buffer Descriptor Offsets */
#define XAXICDMA_BD_NDESC_OFFSET     0x00
#define XAXICDMA_BD_BUFSRC_OFFSET    0x08
#define XAXICDMA_BD_BUFDST_OFFSET    0x10
#define XAXICDMA_BD_CTRL_LEN_OFFSET  0x18
#define XAXICDMA_BD_STS_OFFSET       0x1C

#define XAXICDMA_BD_HW_NUM_BYTES     32

/* Buffer Descriptor Bitmasks */
#define XAXICDMA_BD_CTRL_LENGTH_MASK 0x007FFFFF
#define XAXICDMA_BD_STS_COMPLETE_MASK 0x80000000
#define XAXICDMA_BD_STS_ALL_ERR_MASK  0x70000000
#define XAXICDMA_BD_STS_ALL_MASK      0xF0000000

/***************** Register Access Macros *********************/

/* Wrapper around ioread32/iowrite32 */
#define XAxiCdma_ReadReg(BaseAddress, RegOffset) \
    ioread32((BaseAddress) + (RegOffset))

#define XAxiCdma_WriteReg(BaseAddress, RegOffset, Data) \
    iowrite32((BaseAddress) + (RegOffset), (Data))

#ifdef __cplusplus
}
#endif

#endif /* XAXICDMA_HW_H_ */

