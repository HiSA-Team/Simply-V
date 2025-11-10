#include "uninasoc.h"
#include <stdio.h>
#include "xaxicdma.h"
#include "xaxicdma_hw.h"
#include "io.h"
#include "tinyIO.h" 
#define puts(str)   c_printf("%s\n", str)
#define printf      c_printf
extern const volatile uint32_t _peripheral_AXI_CDMA_start;
#define CDMA_BASEADDR   ((uintptr_t)&_peripheral_AXI_CDMA_start)
#define MEM_BASEADDR 0x00000000  // indirizzo base BRAM
#define SRC_ADDR (MEM_BASEADDR)
#define DST_ADDR (MEM_BASEADDR + 0x1000)

#define LENGTH   256

XAxiCdma_Config CdmaCfg = {
    .DeviceId = 0,
    .BaseAddress = CDMA_BASEADDR,
    .HasDRE = 1,
    .IsLite = 0,
    .DataWidth = 32,
    .BurstLen = 16,
    .AddrWidth = 32
};

XAxiCdma CdmaInstance;

int main(void)
{
    uninasoc_init();
    puts("AXI CDMA test starting..."); 
    printf("\r\n[CDMA] Simple DMA test start\r\n");

    if (XAxiCdma_CfgInitialize(&CdmaInstance, &CdmaCfg, CDMA_BASEADDR) != 0) {
        printf("[CDMA] Init failed\r\n");
        while (1);
    }

    volatile uint32_t *src = (uint32_t *)SRC_ADDR;
    volatile uint32_t *dst = (uint32_t *)DST_ADDR;

    for (int i = 0; i < (LENGTH / 4); i++) {
        src[i] = 0xA5A50000 + i;
        dst[i] = 0xffffffff;
    }

    printf("[CDMA] Starting transfer...\r\n");

    if (XAxiCdma_SimpleTransfer(&CdmaInstance, SRC_ADDR, DST_ADDR, LENGTH, NULL, NULL) != 0) {
        printf("[CDMA] Transfer start failed\r\n");
        while (1);
    }

    while (XAxiCdma_IsBusy(&CdmaInstance));

    int errors = 0;
    for (int i = 0; i < (LENGTH / 4); i++) {
        if (dst[i] != src[i]) {
            errors++;
            printf("[CDMA] Mismatch @%d: src=0x%08x dst=0x%08x\r\n", i, src[i], dst[i]);
        }
    }

    if (errors == 0)
        printf("[CDMA] Transfer OK\r\n");
    else
        printf("[CDMA] Transfer ERROR (%d mismatches)\r\n", errors);

    while (1);
    return 0;
}

