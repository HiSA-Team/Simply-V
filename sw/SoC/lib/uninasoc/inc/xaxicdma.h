/******************************************************************************
* Simplified & adapted for UninaSoC / Baremetal RISC-V
* Original Copyright (C) Xilinx, Inc. / AMD
* SPDX-License-Identifier: MIT
******************************************************************************/

#ifndef XAXICDMA_H_
#define XAXICDMA_H_

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include "io.h"          // for ioread32 / iowrite32
#include "string.h"      // for memset
#include "xaxicdma_bd.h" // keep BD structures if used

/************************** Constant Definitions *****************************/

#define XAXICDMA_COALESCE_NO_CHANGE  0xFFFFFFFF
#define XAXICDMA_ALL_BDS             0x7FFFFFFF

#define XAXICDMA_SG_MODE        1
#define XAXICDMA_SIMPLE_MODE    2

#define XAXICDMA_MAXIMUM_MAX_HANDLER 20

#define XAXICDMA_KEYHOLE_READ   0
#define XAXICDMA_KEYHOLE_WRITE  1

/**************************** Type Definitions *******************************/

typedef void (*XAxiCdma_CallBackFn)(void *CallBackRef, uint32_t IrqMask, int *NumBdPtr);

typedef struct {
    XAxiCdma_CallBackFn CallBackFn;
    void *CallBackRef;
    volatile int NumBds;
} XAxiCdma_IntrHandlerList;

typedef struct {
    uint32_t DeviceId;
    uintptr_t BaseAddress;
    int HasDRE;
    int IsLite;
    int DataWidth;
    int BurstLen;
    int AddrWidth;
} XAxiCdma_Config;

typedef struct {
    uintptr_t BaseAddr;
    int Initialized;
    int SimpleOnlyBuild;
    int HasDRE;
    int IsLite;
    int WordLength;
    int MaxTransLen;
    int SimpleNotDone;
    int SGWaiting;

    uintptr_t FirstBdPhysAddr;
    uintptr_t FirstBdAddr;
    uintptr_t LastBdAddr;
    uint32_t BdRingTotalLen;
    uint32_t BdSeparation;
    void *FreeBdHead;
    void *PreBdHead;
    void *HwBdHead;
    void *HwBdTail;
    void *PostBdHead;
    void *BdaRestart;
    int FreeBdCnt;
    int PreBdCnt;
    int HwBdCnt;
    int PostBdCnt;
    int AllBdCnt;

    XAxiCdma_CallBackFn SimpleCallBackFn;
    void *SimpleCallBackRef;

    int SgHandlerHead;
    int SgHandlerTail;
    XAxiCdma_IntrHandlerList Handlers[XAXICDMA_MAXIMUM_MAX_HANDLER];

    int AddrWidth;
} XAxiCdma;

/***************** Cache Macros (NOPs for RISC-V) *********************/

#define XAXICDMA_CACHE_FLUSH(BdPtr)
#define XAXICDMA_CACHE_INVALIDATE(BdPtr)

/************************** Function Prototypes ******************************/

void XAxiCdma_DumpRegisters(XAxiCdma *InstancePtr);
XAxiCdma_Config *XAxiCdma_LookupConfig(uint32_t DeviceId);
uint32_t XAxiCdma_CfgInitialize(XAxiCdma *InstancePtr, XAxiCdma_Config *CfgPtr, uintptr_t EffectiveAddr);
void XAxiCdma_Reset(XAxiCdma *InstancePtr);
int XAxiCdma_ResetIsDone(XAxiCdma *InstancePtr);
int XAxiCdma_IsBusy(XAxiCdma *InstancePtr);
uint32_t XAxiCdma_SimpleTransfer(XAxiCdma *InstancePtr, uintptr_t SrcAddr, uintptr_t DstAddr,
                                 int Length, XAxiCdma_CallBackFn SimpleCallBack, void *CallbackRef);

void XAxiCdma_IntrEnable(XAxiCdma *InstancePtr, uint32_t Mask);
void XAxiCdma_IntrDisable(XAxiCdma *InstancePtr, uint32_t Mask);
uint32_t XAxiCdma_IntrGetEnabled(XAxiCdma *InstancePtr);
uint32_t XAxiCdma_GetError(XAxiCdma *InstancePtr);

#ifdef __cplusplus
}
#endif

#endif /* XAXICDMA_H_ */

