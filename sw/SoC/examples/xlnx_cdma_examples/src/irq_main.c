// Author: Michele Giugliano <michele.giugliano2@studenti.unina.it>
// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
//   Example demonstrating the use of the AXI CDMA in Simple Transfer mode
//   using interrupt handling through the RISC-V PLIC.
//   The program configures the CDMA engine, enables its interrupt sources,
//   registers the external interrupt handler, and manages transfer completion
//   using ISR-driven notification. It also verifies data integrity after transfer.
//
//   This example is intended for validating proper CDMA+PLIC
//   integration on the Simply-V SoC.

#include "uninasoc.h"
#include <stdint.h>

// Test Parameters
#define NUM_ROUNDS  3
#define NUM_WORDS  16u
#define TRANSFER_SIZE (NUM_WORDS * sizeof(uint32_t))
#define BUFFER_SIZE (NUM_ROUNDS * TRANSFER_SIZE)

// CDMA Base Address (from linker script)
extern const volatile uint32_t _peripheral_CDMA_start;
#define CDMA_BASEADDR   ((uintptr_t)&_peripheral_CDMA_start)

// TODO: import this from config
#define CDMA_IRQ_ID  6
#define CDMA_INT_PRIORITY 1

// Global variable for ISR/main synchronization
static volatile int cdma_done = 0;
// Global CDMA Struct and config
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

// External Interrupt Handler (for PLIC)
void _ext_handler(void) {
    printf("[CDMA IRQ][ISR] Call to %s!\r\n", __func__ );

    uint32_t interrupt_id = plic_claim();

    // If interrupt is from CDMA
    if (interrupt_id == CDMA_IRQ_ID) {
        printf("[CDMA IRQ][ISR] Handiling CDMA interrupt!\r\n");
        // Red status register
        uint32_t sr = XAxiCdma_ReadReg(cdma_handle.BaseAddr, XAXICDMA_SR_OFFSET);
        // Check if it is IOC
        if (sr & XAXICDMA_XR_IRQ_IOC_MASK)
            cdma_done = 1;

        // Check if it is ERROR
        if (sr & XAXICDMA_XR_IRQ_ERROR_MASK)
            printf("[CDMA IRQ][ISR] CDMA ERROR SR=0x%08x\n\r", sr);

        // Acknowledge interrupt to CDMA
        XAxiCdma_WriteReg(cdma_handle.BaseAddr, XAXICDMA_SR_OFFSET, XAXICDMA_XR_IRQ_ALL_MASK);

        // Mark transfer as done
        XAxiCdma_TransferDone(&cdma_handle);
    }
    else {
        // Unkown interrupt source
        printf("[CDMA IRQ][ISR] Unrecognized interrupt id %u!\n\r", interrupt_id);
    }

    // Notify completion
    plic_complete(interrupt_id);
}

int main(void) {

    // Source and destination buffers
    uint32_t src [NUM_ROUNDS][NUM_WORDS];
    uint32_t dst [NUM_ROUNDS][NUM_WORDS];
    uint32_t errors = 0;

    // Initialize platform
    uninasoc_init();

    printf("\n\r[CDMA IRQ] CDMA Interrupt Test\n\r");

    // Init CDMA
    if (XAxiCdma_CfgInitialize(&cdma_handle, &CdmaCfg, CDMA_BASEADDR) != 0) {
        printf("[CDMA IRQ] XAxiCdma_CfgInitialize failed\n");
        return -1;
    }

    // Reset CDMA
    printf("[CDMA IRQ] Reset CDMA...\n\r");
    XAxiCdma_Reset(&cdma_handle);
    // Wait for ResetIsDone
    while (!XAxiCdma_ResetIsDone(&cdma_handle));
    printf("[CDMA IRQ] Reset complete\n\r");

    // Enable CDMA interrupts: IOC + ERROR
    XAxiCdma_IntrEnable(&cdma_handle, XAXICDMA_XR_IRQ_IOC_MASK | XAXICDMA_XR_IRQ_ERROR_MASK);
    XAxiCdma_DumpRegisters(&cdma_handle);

    // Init and configure PLIC
    printf("[CDMA IRQ] Configure PLIC...\n\r");
    plic_init();
    plic_configure_set_one(CDMA_INT_PRIORITY, CDMA_IRQ_ID);
    plic_enable_all();

    // For NUM_ROUNDS
    for ( uint32_t round = 0; round < NUM_ROUNDS; round++ ) {

        // Prepare buffers
        for (uint32_t word = 0; word < TRANSFER_SIZE; word++) {
            src[round][word] = ((round & 0xFu) << 28) ^ (word * 0x11111111u) ^ 0x76543210u;
            dst[round][word] = 0xffffffffu;
        }
        // Show initial contents
        printf("[CDMA IRQ] Buffers before transfer:\n\r");
        for (uint32_t word = 0; word < NUM_WORDS; word++) {
            printf("src[%u] = 0x%08X | dst[%u] = 0x%08X\n\r", word, src[round][word], word, dst[round][word]);
        }

        // Reset synchronization variable
        cdma_done = 0;

        // Start CDMA transfer
        printf("[CDMA IRQ] Starting CDMA transfer...\n\r");
        uint32_t ret = XAxiCdma_SimpleTransfer(&cdma_handle,
                                        (uintptr_t)(src[round]),
                                        (uintptr_t)(dst[round]),
                                        BUFFER_SIZE,
                                        NULL, NULL);
        if (ret != 0) {
            uint32_t cr = XAxiCdma_ReadReg(cdma_handle.BaseAddr, XAXICDMA_CR_OFFSET);
            uint32_t sr = XAxiCdma_ReadReg(cdma_handle.BaseAddr, XAXICDMA_SR_OFFSET);
            printf("[CDMA IRQ] SimpleTransfer failed (%d)  CR=0x%08x SR=0x%08x\n\r",
                ret, cr, sr);
        }

        // Wait for IRQ to set synchronization flag (soft wfi)
        while (!cdma_done);

        // Verify result
        printf("[CDMA IRQ] Buffers after transfer:\n\r");
        for (uint32_t i = 0; i < NUM_WORDS; i++) {
            if (dst[round][i] != src[round][i]){
                errors++;
            }
            if (i < NUM_WORDS) {
                printf("src[%u] = 0x%08X | dst[%u] = 0x%08X\n\r", i, src[round][i], i, dst[round][i]);
            }
        }

        // Print on errors
        if (errors == 0)
            printf("[CDMA IRQ] Round %u: Transfer OK, all %u words match\n\r", round, NUM_WORDS);
        else {
            printf("[CDMA IRQ] Round %u: Transfer ERROR,  mismatches=%u\n\r", errors);
            return errors;
        }
    }

    printf("[CDMA IRQ] All %u rounds completed\n\r", NUM_ROUNDS);

    return 0;
}

