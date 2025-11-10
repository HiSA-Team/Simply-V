#ifndef XAXICDMA_BD_H_
#define XAXICDMA_BD_H_

#include <stdint.h>

typedef struct {
    uint32_t NextDesc;
    uint32_t SrcAddr;
    uint32_t DstAddr;
    uint32_t Control;
    uint32_t Status;
} XAxiCdma_Bd;

#endif

