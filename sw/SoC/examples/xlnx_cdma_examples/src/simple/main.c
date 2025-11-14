/*
 * Author: Michele Giugliano <michele.giugliano2@studenti.unina.it>
 * Description:
 *   Example demonstrating the use of the AXI CDMA in Simple Transfer mode.
 *   The program performs multiple consecutive transfer rounds, each using
 *   a different transfer length. For every round it:
 *     - prepares source and destination buffers,
 *     - starts a CDMA simple transfer in polling mode,
 *     - waits for completion,
 *     - and verifies data integrity.
 *
 *   This example is useful to validate CDMA behavior across different
 *   transfer sizes and to stress-test basic DMA functionality.
 */

#include "uninasoc.h"
#include "xaxicdma.h"
#include "xaxicdma_hw.h"
#include <stdint.h>


/* ============================================================
 *                 CDMA Base Address (from linker)
 * ============================================================ */
extern const volatile uint32_t _peripheral_AXI_CDMA_start;
#define CDMA_BASEADDR   ((uintptr_t)&_peripheral_AXI_CDMA_start)

/* ============================================================
 *                  Simple BRAM Address Map
 * ============================================================ */
#define MEM_BASEADDR    0x00000000u
#define SRC_ADDR        (MEM_BASEADDR + 0x0000u)
#define DST_ADDR        (MEM_BASEADDR + 0x1000u)

/* ============================================================
 *                 Multi-Round Test Parameters
 * ============================================================ */
#define ROUNDS  3u

/* Number of 32-bit words to transfer for each round */
static const uint32_t WORDS_ROUND[ROUNDS] = {
    8u,   /* Round 0:  8 words  ( 32 bytes) */
    16u,  /* Round 1: 16 words  ( 64 bytes) */
    32u   /* Round 2: 32 words (128 bytes) */
};

/* ============================================================
 *                   CDMA Driver Structures
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
 *                      Debug / Status Print
 * ============================================================ */
static void cdma_print_status(const char* tag)
{
    uint32_t sr = XAxiCdma_ReadReg(CDMA_BASEADDR, XAXICDMA_SR_OFFSET);
    printf("%s SR=0x%08X\n", tag, sr);
}

/* ============================================================
 *  Run a single transfer round:
 *   - fills source and destination buffers
 *   - runs a simple CDMA transfer
 *   - checks the result
 * ============================================================ */
static int do_one_round(uint32_t round_idx, uint32_t words)
{
    volatile uint32_t* src = (uint32_t*)SRC_ADDR;
    volatile uint32_t* dst = (uint32_t*)DST_ADDR;
    const uint32_t bytes = words * 4u;

    /* Round banner */
    printf("\n=== Round %u — words %u ===\n", round_idx, words);

    /*
     * Fill source with a round-dependent pattern and destination with 0xFFFFFFFF.
     * Pattern:
     *   src[i] = (round_idx << 28) ^ (i * 0x11111111) ^ 0xA5A5A5A5
     */
    for (uint32_t i = 0; i < words; i++) {
        src[i] = ((round_idx & 0xFu) << 28) ^ (i * 0x11111111u) ^ 0xA5A5A5A5u;
        dst[i] = 0xFFFFFFFFu;
    }

    /* Show initial contents (limited preview) */
    printf("Before transfer:\n");
    uint32_t preview = (words < 8u) ? words : 8u;
    for (uint32_t i = 0; i < preview; i++) {
        printf("SRC[%u] = 0x%08X | DST[%u] = 0x%08X\n",
               i, src[i], i, dst[i]);
    }

    cdma_print_status("CDMA Status before transfer:");

    /* Start simple transfer */
    printf("Starting CDMA transfer (%u bytes)...\n", bytes);
    int st = XAxiCdma_SimpleTransfer(&Cdma, SRC_ADDR, DST_ADDR, (int)bytes, NULL, NULL);
    if (st != 0) {
        printf("[CDMA] Transfer start failed (error=%d)\n", st);
        cdma_print_status("CDMA Status after failure:");
        return -1;
    }

    /* Poll for completion with a simple timeout guard */
    {
        uint32_t guard = 0;
        while (XAxiCdma_IsBusy(&Cdma)) {
            if (++guard > 10000000u) {
                printf("[CDMA] Timeout while waiting for completion\n");
                cdma_print_status("CDMA Status on timeout:");
                return -2;
            }
        }
    }

    printf("[CDMA] Transfer complete.\n");
    cdma_print_status("CDMA Status after transfer:");

    /* Verify data and print first few words */
    printf("After transfer:\n");
    uint32_t errors = 0;

    for (uint32_t i = 0; i < words; i++) {
        if (dst[i] != src[i])
            errors++;

        if (i < preview) {
            printf("SRC[%u] = 0x%08X | DST[%u] = 0x%08X\n",
                   i, src[i], i, dst[i]);
        }
    }

    if (errors == 0) {
        printf("Round OK — all %u words copied correctly\n", words);
        return 0;
    } else {
        printf("Round ERROR — mismatches: %u\n", errors);
        return (int)errors;
    }
}

/* ============================================================
 *                           MAIN
 * ============================================================ */
int main(void)
{
    /* Initialize UART / platform */
    uninasoc_init();

    printf("\nCDMA multi-round transfer test start\n");

    /* Initialize CDMA core */
    if (XAxiCdma_CfgInitialize(&Cdma, &CdmaCfg, CDMA_BASEADDR) != 0) {
        printf("[CDMA] Initialization failed\n");
        while (1);
    }

    /* Initial reset */
    printf("Resetting CDMA...\n");
    XAxiCdma_Reset(&Cdma);
    for (volatile uint32_t t = 0; t < 50000; t++) __asm__ __volatile__("");
    printf("[CDMA] Reset complete\n");
    cdma_print_status("CDMA Status after reset:");

    /* Execute multiple rounds with different sizes */
    for (uint32_t r = 0; r < ROUNDS; r++) {
        int res = do_one_round(r, WORDS_ROUND[r]);

        /* Reset CDMA between rounds to keep behavior consistent */
        XAxiCdma_Reset(&Cdma);
        for (volatile uint32_t i = 0; i < 50000; i++) __asm__ __volatile__("");
        Cdma.SimpleNotDone = 0;  /* clear internal state used by driver */

        if (res != 0) {
            printf("Stopping due to error in round %u\n", r);
            break;
        }
    }

    printf("\nAll rounds completed\n");
    while (1);
    return 0;
}

