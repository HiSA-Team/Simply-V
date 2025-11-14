/*
 * Author: Michele Giugliano <michele.giugliano2@studenti.unina.it>
 * Description:
 *   Example demonstrating multiple AXI CDMA Simple Transfer operations with
 *   different transfer sizes. The program performs a DMA transaction copying
 *   a configurable number of words from a source buffer in BRAM to a
 *   destination buffer. It prints diagnostic information before and after the
 *   transfer and checks that all words have been copied correctly.
 *
 *   This example is useful for validating AXI CDMA behavior when handling
 *   back-to-back transactions of varying data sizes. All output uses printf().
 */

#include "uninasoc.h"
#include "xaxicdma.h"
#include "xaxicdma_hw.h"
#include <stdint.h>


/* ============================================================
 *                  CDMA Base Address (from linker)
 * ============================================================ */
extern const volatile uint32_t _peripheral_AXI_CDMA_start;
#define CDMA_BASEADDR ((uintptr_t)&_peripheral_AXI_CDMA_start)

/* ============================================================
 *                BRAM Layout for Source and Destination
 * ============================================================ */
#define MEM_BASEADDR  0x00000000u
#define SRC_ADDR      (MEM_BASEADDR + 0x0000u)
#define DST_ADDR      (MEM_BASEADDR + 0x1000u)

/* ============================================================
 *                     Transfer Configuration
 * ============================================================ */
#define WORDS  16u
#define BYTES  (WORDS * 4u)

/* ============================================================
 *                CDMA Driver Instance and Configuration
 * ============================================================ */
static XAxiCdma Cdma;

static XAxiCdma_Config CdmaCfg = {
    .DeviceId    = 0,
    .BaseAddress = CDMA_BASEADDR,
    .HasDRE      = 1,
    .IsLite      = 0,
    .DataWidth   = 32,
    .BurstLen    = 16,
    .AddrWidth   = 32
};

/* ============================================================
 *                        Debug Utilities
 * ============================================================ */
static void cdma_print_status(const char* tag)
{
    uint32_t s = XAxiCdma_ReadReg(CDMA_BASEADDR, XAXICDMA_SR_OFFSET);
    printf("%s  SR=0x%08X\n", tag, s);
}

/* ============================================================
 *                             MAIN
 * ============================================================ */
int main(void)
{
    uninasoc_init();

    printf("\n=== CDMA Multi-Word Transfer Test ===\n");

    /* Initialize CDMA */
    if (XAxiCdma_CfgInitialize(&Cdma, &CdmaCfg, CDMA_BASEADDR) != 0) {
        printf("[CDMA] Initialization failed\n");
        while (1);
    }

    /* Reset CDMA */
    printf("Resetting CDMA...\n");
    XAxiCdma_Reset(&Cdma);
    for (volatile uint32_t t = 0; t < 50000; t++) __asm__ volatile ("");
    printf("[CDMA] Reset complete\n");

    cdma_print_status("CDMA Status:");

    /* Prepare buffers */
    volatile uint32_t* src = (uint32_t*)SRC_ADDR;
    volatile uint32_t* dst = (uint32_t*)DST_ADDR;

    for (uint32_t i = 0; i < WORDS; i++) {
        src[i] = (i * 0x11111111u) ^ 0xA5A5A5A5u;  /* test pattern */
        dst[i] = 0xFFFFFFFFu;
    }

    /* Show initial state */
    printf("Before transfer:\n");
    for (uint32_t i = 0; i < (WORDS < 8 ? WORDS : 8); i++) {
        printf("SRC[%u] = 0x%08X\n", i, src[i]);
    }
    for (uint32_t i = 0; i < (WORDS < 8 ? WORDS : 8); i++) {
        printf("DST[%u] = 0x%08X\n", i, dst[i]);
    }

    cdma_print_status("CDMA Status:");

    /* Start transfer */
    printf("Starting CDMA transfer (%u bytes)...\n", BYTES);

    int st = XAxiCdma_SimpleTransfer(&Cdma, SRC_ADDR, DST_ADDR, BYTES, NULL, NULL);
    if (st != 0) {
        printf("[CDMA] Transfer start failed (error=%d)\n", st);
        cdma_print_status("CDMA Status:");
        while (1);
    }

    /* Poll for completion */
    uint32_t guard = 0;
    while (XAxiCdma_IsBusy(&Cdma)) {
        if (++guard > 10000000u) {
            printf("[CDMA] Timeout while waiting for completion\n");
            cdma_print_status("CDMA Status:");
            while (1);
        }
    }

    printf("[CDMA] Transfer complete\n");
    cdma_print_status("CDMA Status:");

    /* Verify results */
    printf("After transfer:\n");

    uint32_t errors = 0;

    for (uint32_t i = 0; i < WORDS; i++) {
        if (dst[i] != src[i])
            errors++;

        if (i < 8) {
            printf("SRC[%u] = 0x%08X | DST[%u] = 0x%08X\n",
                   i, src[i], i, dst[i]);
        }
    }

    if (errors == 0)
        printf("Transfer OK — all %u words copied correctly\n", WORDS);
    else
        printf("Transfer ERROR — mismatches detected: %u\n", errors);

    while (1);
    return 0;
}

