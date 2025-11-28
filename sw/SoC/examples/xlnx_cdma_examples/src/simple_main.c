// Author: Michele Giugliano <michele.giugliano2@studenti.unina.it>
// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
//   Example demonstrating the use of the AXI CDMA in Simple Transfer mode.
//   The program performs multiple consecutive transfer NUM_ROUNDS, each using
//   a different transfer length. For every round it:
//     - prepares source and destination buffers,
//     - starts a CDMA simple transfer,
//     - waits for completion in polling,
//     - and verifies data integrity.
//
//   This example is useful to validate CDMA behavior across different
//   transfer sizes and to stress-test basic DMA functionality.

#include "uninasoc.h"
#include <stdint.h>

// CDMA Base Address (from linker script)
extern const volatile uint32_t _peripheral_CDMA_start;
#define CDMA_BASEADDR   ((uintptr_t)&_peripheral_CDMA_start)

// Multi-Round Test Parameters
#define NUM_ROUNDS  3u
#define BUFFER_SIZE 128u

// Number of 32-bit num_words to transfer for each roun
static const uint32_t WORDS_ROUND[NUM_ROUNDS] = {
    8u,   // Round 0:  8 num_words  ( 32 bytes)
    16u,  // Round 1: 16 num_words  ( 64 bytes)
    32u   // Round 2: 32 num_words (128 bytes)
};

// Run a single transfer round:
//  - fills source and destination buffers
//  - runs a simple CDMA transfer
//  - checks the result
uint32_t cdma_do_one_round (
                XAxiCdma* CdmaHandle,
                uint32_t round_idx,
                uint32_t* src,
                uint32_t* dst,
                uint32_t num_words
        ) {

    // Round banner
    printf("[CDMA SIMPLE] ----------- Round %u - num_words %u ----------- \n\r", round_idx, num_words);

    // Fill source with a round-dependent pattern and destination with 0xFFFFFFFF.
    for (uint32_t i = 0; i < num_words; i++) {
        src[i] = ((round_idx & 0xFu) << 28) ^ (i * 0x11111111u) ^ 0x76543210u;
        dst[i] = 0xFFFFFFFFu;
    }

    // Show initial contents
    printf("[CDMA SIMPLE] Buffers before transfer:\n\r");
    for (uint32_t i = 0; i < num_words; i++) {
        printf("src[%u] = 0x%08X | dst[%u] = 0x%08X\n\r", i, src[i], i, dst[i]);
    }

    // Debug
    printf("[CDMA SIMPLE] CDMA Status before transfer:");
    XAxiCdma_DumpRegisters(CdmaHandle);

    // Start simple transfer
    uint32_t bytes = sizeof(uint32_t) * num_words;
    printf("[CDMA SIMPLE] Starting CDMA transfer (%u bytes)...\n\r", bytes);
    int st = XAxiCdma_SimpleTransfer(CdmaHandle, (uintptr_t)src, (uintptr_t)dst, bytes, NULL, NULL);
    if (st != 0) {
        printf("[CDMA SIMPLE] Transfer start failed (error=%d)\n\r", st);
        printf("[CDMA SIMPLE] CDMA Status after failure:");
        XAxiCdma_DumpRegisters(CdmaHandle);
        return -1;
    }

    // Poll for completion with a simple timeout guard
    {
        uint32_t guard = 0;
        while (XAxiCdma_IsBusy(CdmaHandle)) {
            if (++guard > 10000000u) {
                printf("[CDMA SIMPLE] Timeout while waiting for completion\n\r");
                printf("[CDMA SIMPLE] CDMA Status on timeout:");
                XAxiCdma_DumpRegisters(CdmaHandle);
                return -2;
            }
        }
    }

    // Debug
    printf("[CDMA SIMPLE] Transfer complete.\n\r");
    XAxiCdma_DumpRegisters(CdmaHandle);

    // Verify data and print first few num_words
    printf("[CDMA SIMPLE] Buffers after transfer:\n\r");
    uint32_t errors = 0;
    for (uint32_t i = 0; i < num_words; i++) {
        if (dst[i] != src[i]){
            errors++;
        }
        if (i < BUFFER_SIZE) {
            printf("src[%u] = 0x%08X | dst[%u] = 0x%08X\n\r", i, src[i], i, dst[i]);
        }
    }

    // Print on errors
    if (errors == 0)
        printf("[CDMA SIMPLE] Round %u OK - all %u num_words copied correctly\n\r", round_idx, num_words);
    else
        printf("[CDMA SIMPLE] Round %u ERROR - mismatches: %u\n\r", round_idx, errors);

    return errors;
}

int main(void) {

    // Source and destination buffers
    uint32_t src [BUFFER_SIZE];
    uint32_t dst [BUFFER_SIZE];

    // CDMA Struct and config
    XAxiCdma cdma_handle;
    XAxiCdma_Config CdmaCfg = {
        .DeviceId    = 0,
        .BaseAddress = CDMA_BASEADDR,
        .HasDRE      = 1,
        .IsLite      = 0,
        .DataWidth   = 32,
        .BurstLen    = 16,
        .AddrWidth   = 32
    };

    // Initialize platform
    uninasoc_init();

    printf("\n[CDMA SIMPLE] CDMA multi-round transfer test start\n\r");

    // Initialize CDMA core
    if (XAxiCdma_CfgInitialize(&cdma_handle, &CdmaCfg, CDMA_BASEADDR) != 0) {
        printf("[CDMA SIMPLE] Initialization failed\n\r");
        return -1;
    }

    // Initial reset
    printf("[CDMA SIMPLE] Resetting CDMA...\n\r");
    XAxiCdma_Reset(&cdma_handle);
    printf("[CDMA SIMPLE] Reset complete\n\r");
    XAxiCdma_DumpRegisters(&cdma_handle);

    // Execute multiple NUM_ROUNDS with different sizes
    for (uint32_t r = 0; r < NUM_ROUNDS; r++) {
        // Launch a single round
        uint32_t res = cdma_do_one_round(
                    &cdma_handle,
                    r,
                    src,
                    dst,
                    WORDS_ROUND[r]
                );

        // Reset CDMA between NUM_ROUNDS to keep behavior consistent
        XAxiCdma_TransferDone(&cdma_handle);

        if (res != 0) {
            printf("[CDMA SIMPLE] Stopping due to error in round %u\n\r", r);
            break;
        }
    }

    printf("[CDMA SIMPLE] All %u rounds completed\n\r", NUM_ROUNDS);

    return 0;
}

