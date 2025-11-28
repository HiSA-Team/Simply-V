// Author: Michele Giugliano <michele.giugliano2@studenti.unina.it>
// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description: AXI CDMA baremetal driver. Simplified & adapted for UninaSoC.
//  Original Copyright (C) Xilinx, Inc. / AMD
//  SPDX-License-Identifier: MIT

#include "xlnx_cdma.h"
#include <stdint.h>
#include "tinyIO.h"

//  Helper macros
#define XST_SUCCESS        0
#define XST_FAILURE       -1
#define XST_INVALID_PARAM -2
#define XST_DEVICE_BUSY   -3
#define XST_NO_FEATURE    -4

#define XAXICDMA_RESET_LOOP_LIMIT  1000000

#define LOWER_32_BITS(x) ((uint32_t)((x) & 0xFFFFFFFFU))
#define UPPER_32_BITS(x) ((uint32_t)(((x) >> 32) & 0xFFFFFFFFU))

// Get the error status bits from the status register.
uint32_t XAxiCdma_GetError(XAxiCdma *InstancePtr) {
    return (XAxiCdma_ReadReg(InstancePtr->BaseAddr, XAXICDMA_SR_OFFSET) &
            XAXICDMA_SR_ERR_ALL_MASK);
}

// Reset the DMA engine.
void XAxiCdma_Reset(XAxiCdma *InstancePtr) {
    XAxiCdma_WriteReg(InstancePtr->BaseAddr, XAXICDMA_CR_OFFSET, XAXICDMA_CR_RESET_MASK);

    InstancePtr->SimpleNotDone = 0;
    // InstancePtr->SGWaiting = 0;
    // InstancePtr->SgHandlerHead = 0;
    // InstancePtr->SgHandlerTail = 0;
    // InstancePtr->SimpleCallBackFn = NULL;
    // InstancePtr->SimpleCallBackRef = NULL;
}

void XAxiCdma_TransferDone(XAxiCdma *InstancePtr) {
    InstancePtr->SimpleNotDone = 0;
}

// Check whether the hardware reset is done.
int XAxiCdma_ResetIsDone(XAxiCdma *InstancePtr) {
    return ((XAxiCdma_ReadReg(InstancePtr->BaseAddr, XAXICDMA_CR_OFFSET) &
             XAXICDMA_CR_RESET_MASK)
                ? 0
                : 1);
}

// Initialize the CDMA driver instance.
uint32_t XAxiCdma_CfgInitialize(XAxiCdma *InstancePtr, XAxiCdma_Config *CfgPtr, uintptr_t EffectiveAddr) {
    uint32_t RegValue;
    int TimeOut;

    InstancePtr->Initialized = 0;
    InstancePtr->BaseAddr = EffectiveAddr;
    InstancePtr->HasDRE = CfgPtr->HasDRE;
    InstancePtr->IsLite = CfgPtr->IsLite;
    InstancePtr->WordLength = ((unsigned int)CfgPtr->DataWidth) >> 3;
    InstancePtr->AddrWidth = CfgPtr->AddrWidth;

    if (InstancePtr->WordLength < 4) {
        printf("[CDMA] Invalid word length: %d\r\n", InstancePtr->WordLength);
        return XST_INVALID_PARAM;
    }

    RegValue = XAxiCdma_ReadReg(InstancePtr->BaseAddr, XAXICDMA_SR_OFFSET);
    InstancePtr->SimpleOnlyBuild = !(RegValue & XAXICDMA_SR_SGINCLD_MASK);

    if (InstancePtr->SimpleOnlyBuild && CfgPtr->IsLite)
        InstancePtr->MaxTransLen = InstancePtr->WordLength * CfgPtr->BurstLen;
    else
        InstancePtr->MaxTransLen = 0x7FFFFF; // Default max transfer length

    XAxiCdma_Reset(InstancePtr);

    TimeOut = XAXICDMA_RESET_LOOP_LIMIT;
    while (TimeOut && !XAxiCdma_ResetIsDone(InstancePtr))
        TimeOut--;

    if (!TimeOut) {
        printf("[CDMA] Reset timeout\r\n");
        return XST_FAILURE;
    }

    InstancePtr->AllBdCnt = 0;
    InstancePtr->FreeBdCnt = 0;
    InstancePtr->HwBdCnt = 0;
    InstancePtr->PreBdCnt = 0;
    InstancePtr->PostBdCnt = 0;
    InstancePtr->Initialized = 1;

    return XST_SUCCESS;
}

// Check if the DMA is busy.
int XAxiCdma_IsBusy(XAxiCdma *InstancePtr) {
    return ((XAxiCdma_ReadReg(InstancePtr->BaseAddr, XAXICDMA_SR_OFFSET) &
             XAXICDMA_SR_IDLE_MASK)
                ? 0
                : 1);
}

// Simple transfer operation (polling or interrupt mode).
uint32_t XAxiCdma_SimpleTransfer(XAxiCdma *InstancePtr,
                                 uintptr_t SrcAddr,
                                 uintptr_t DstAddr,
                                 int Length,
                                 XAxiCdma_CallBackFn SimpleCallBack,
                                 void *CallBackRef) {
    uint32_t WordMask;

    if ((Length < 1) || (Length > 0x7FFFFF))
        return XST_INVALID_PARAM;

    WordMask = (uint32_t)(InstancePtr->WordLength - 1);

    if (((SrcAddr & WordMask) || (DstAddr & WordMask)) && !InstancePtr->HasDRE) {
        printf("[CDMA] Unaligned transfer without DRE support\r\n");
        return XST_INVALID_PARAM;
    }

    if (XAxiCdma_IsBusy(InstancePtr)) {
        printf("[CDMA] Engine busy\r\n");
        return XST_FAILURE;
    }

    if (InstancePtr->SimpleNotDone) {
        printf("[CDMA] Previous transfer still pending\r\n");
        return XST_FAILURE;
    }

    InstancePtr->SimpleNotDone = 1;
    // InstancePtr->SimpleCallBackFn = SimpleCallBack;
    // InstancePtr->SimpleCallBackRef = CallBackRef;

    XAxiCdma_WriteReg(InstancePtr->BaseAddr, XAXICDMA_SRCADDR_OFFSET, LOWER_32_BITS(SrcAddr));
    XAxiCdma_WriteReg(InstancePtr->BaseAddr, XAXICDMA_DSTADDR_OFFSET, LOWER_32_BITS(DstAddr));
    XAxiCdma_WriteReg(InstancePtr->BaseAddr, XAXICDMA_BTT_OFFSET, Length);

    return XST_SUCCESS;
}

// Print register contents (debug).
void XAxiCdma_DumpRegisters(XAxiCdma *InstancePtr) {
    uintptr_t base = InstancePtr->BaseAddr;

    printf("\r\n=== AXI CDMA Registers ===\r\n");
    printf("CR   : 0x%08x\r\n", XAxiCdma_ReadReg(base, XAXICDMA_CR_OFFSET));
    printf("SR   : 0x%08x\r\n", XAxiCdma_ReadReg(base, XAXICDMA_SR_OFFSET));
    printf("SRC  : 0x%08x\r\n", XAxiCdma_ReadReg(base, XAXICDMA_SRCADDR_OFFSET));
    printf("DST  : 0x%08x\r\n", XAxiCdma_ReadReg(base, XAXICDMA_DSTADDR_OFFSET));
    printf("BTT  : 0x%08x\r\n", XAxiCdma_ReadReg(base, XAXICDMA_BTT_OFFSET));
    printf("==========================\r\n");
}

// Get pending interrupts.
uint32_t XAxiCdma_IntrGetIrq(XAxiCdma *InstancePtr) {
    // Restituisce solo i bit di IRQ (IOC ed ERROR) presi dallo status
    uint32_t sr = XAxiCdma_ReadReg(InstancePtr->BaseAddr, XAXICDMA_SR_OFFSET);
    return sr & (XAXICDMA_XR_IRQ_IOC_MASK | XAXICDMA_XR_IRQ_ERROR_MASK);
}

// Acknowledge interrupt handling.
void XAxiCdma_IntrAckIrq(XAxiCdma *InstancePtr, uint32_t Mask) {
    // Ack degli IRQ scrivendo i bit corrispondenti nello SR
    XAxiCdma_WriteReg(InstancePtr->BaseAddr, XAXICDMA_SR_OFFSET, Mask);
}

// Enable interrupts in the CDMA core.
void XAxiCdma_IntrEnable(XAxiCdma *InstancePtr, uint32_t Mask) {
    uint32_t RegValue;

    RegValue = XAxiCdma_ReadReg(InstancePtr->BaseAddr, XAXICDMA_CR_OFFSET);
    RegValue |= (Mask & XAXICDMA_XR_IRQ_ALL_MASK);
    XAxiCdma_WriteReg(InstancePtr->BaseAddr, XAXICDMA_CR_OFFSET, RegValue);
}

// Disable interrupts in the CDMA core.
void XAxiCdma_IntrDisable(XAxiCdma *InstancePtr, uint32_t Mask) {
    uint32_t RegValue;

    RegValue = XAxiCdma_ReadReg(InstancePtr->BaseAddr, XAXICDMA_CR_OFFSET);
    RegValue &= ~(Mask & XAXICDMA_XR_IRQ_ALL_MASK);
    XAxiCdma_WriteReg(InstancePtr->BaseAddr, XAXICDMA_CR_OFFSET, RegValue);
}