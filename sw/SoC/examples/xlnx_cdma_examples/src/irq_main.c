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
#include "xaxicdma.h" // TODO: remove me!
#include "xaxicdma_hw.h" // TODO: remove me!
#include <stdint.h>

// Test Parameters
#define NUM_WORDS  16u
#define BUFFER_SIZE (NUM_WORDS * sizeof(uint32_t))

// CDMA Base Address (from linker script)
extern const volatile uint32_t _peripheral_AXI_CDMA_start;
#define CDMA_BASEADDR   ((uintptr_t)&_peripheral_AXI_CDMA_start)

// TODO: import this from config
#define CDMA_IRQ_ID  6

// Global variable for ISR/main synchronization
static volatile int cdma_done = 0;
// CDMA Struct and config
XAxiCdma Cdma;
XAxiCdma_Config CdmaCfg = {
    .DeviceId    = 0,
    .BaseAddress = CDMA_BASEADDR,
    .HasDRE      = 1,
    .IsLite      = 0,
    .DataWidth   = 32,
    .BurstLen    = 16,
    .AddrWidth   = 32
};

// Utilities
void dump_buffers(const char* tag, uint32_t* src, uint32_t* dst, uint32_t num_words){
    printf("%s\n\r", tag);
    for (uint32_t i = 0; i < num_words; i++)
        printf("SRC[%u]=0x%08x | DST[%u]=0x%08x\n\r", i, src[i], i, dst[i]);
}

// External Interrupt Handler (for PLIC)
void _ext_handler(void) {
    printf("Call to _ext_handler!\r\n");

    uint32_t interrupt_id = plic_claim();

    // If interrupt is from CDMA
    if (interrupt_id == CDMA_IRQ_ID) {
        printf("Handiling CDMA interrupt!\r\n");
        // Red status register
        uint32_t sr = XAxiCdma_ReadReg(Cdma.BaseAddr, XAXICDMA_SR_OFFSET);
        // Check if it is IOC
        if (sr & XAXICDMA_XR_IRQ_IOC_MASK)
            cdma_done = 1;

        // Check if it is ERROR
        if (sr & XAXICDMA_XR_IRQ_ERROR_MASK)
            printf("[ISR] CDMA ERROR SR=0x%08x\n\r", sr);

        // Acknowledge interrupt to CDMA
        XAxiCdma_WriteReg(Cdma.BaseAddr, XAXICDMA_SR_OFFSET, XAXICDMA_XR_IRQ_ALL_MASK);
    }
    else {
        // Unkown interrupt source
        printf("[ISR] Unrecognized interrupt id %u!\n\r", interrupt_id);
    }

    // Notify completion
    plic_complete(interrupt_id);
}

int main(void) {

    // Source and destination buffers
    uint32_t src [BUFFER_SIZE];
    uint32_t dst [BUFFER_SIZE];

    // Initialize platform
    uninasoc_init();

    printf("\n\r[CDMA IRQ] CDMA Interrupt Test\n\r");

    // Init CDMA
    if (XAxiCdma_CfgInitialize(&Cdma, &CdmaCfg, CDMA_BASEADDR) != 0) {
        printf("[CDMA IRQ] XAxiCdma_CfgInitialize failed\n");
        return -1;
    }

    // Reset DCMA
    printf("[CDMA IRQ] Reset CDMA...\n\r");
    XAxiCdma_Reset(&Cdma);
    // Wait for ResetIsDone
    while (!XAxiCdma_ResetIsDone(&Cdma));
    printf("[CDMA IRQ] Reset complete\n\r");

    // Enable CDMA interrupts: IOC + ERROR
    XAxiCdma_IntrEnable(&Cdma, XAXICDMA_XR_IRQ_IOC_MASK | XAXICDMA_XR_IRQ_ERROR_MASK);
    XAxiCdma_DumpRegisters(&Cdma);

    // Init and configure PLIC
    printf("[CDMA IRQ] Configure PLIC...n\r");
    plic_init();
    #define CDMA_INT_PRIORITY 1
    plic_configure_set_one(CDMA_INT_PRIORITY, CDMA_IRQ_ID);
    plic_enable_all();

    // Prepare buffers
    for (uint32_t i = 0; i < NUM_WORDS; i++) {
        src[i] = (i * 0x11111111u) ^ 0x76543210u;
        dst[i] = 0xffffffffu;
    }
    // Show initial contents
    printf("[CDMA SIMPLE] Buffers before transfer:\n\r");
    for (uint32_t i = 0; i < NUM_WORDS; i++) {
        printf("src[%u] = 0x%08X | dst[%u] = 0x%08X\n\r", i, src[i], i, dst[i]);
    }

    // Reset synchronization variable
    cdma_done = 0;

    // Start CDMA transfer
    printf("Starting CDMA transfer...\n\r");
    uint32_t ret = XAxiCdma_SimpleTransfer(&Cdma,
                                     (uintptr_t)src,
                                     (uintptr_t)dst,
                                     BUFFER_SIZE,
                                     NULL, NULL);
    if (ret != 0) {
        uint32_t cr = XAxiCdma_ReadReg(Cdma.BaseAddr, XAXICDMA_CR_OFFSET);
        uint32_t sr = XAxiCdma_ReadReg(Cdma.BaseAddr, XAXICDMA_SR_OFFSET);
        printf("[CDMA IRQ] SimpleTransfer failed (%d)  CR=0x%08x SR=0x%08x\n\r",
               ret, cr, sr);
    }

    // Wait for IRQ to set synchronization flag (soft wfi)
    while (!cdma_done);

    // Verify result
    printf("Buffers after transfer:\n\r");
    uint32_t errors = 0;
    for (uint32_t i = 0; i < NUM_WORDS; i++) {
        if (dst[i] != src[i]){
            errors++;
        }
        if (i < NUM_WORDS) {
            printf("src[%u] = 0x%08X | dst[%u] = 0x%08X\n\r", i, src[i], i, dst[i]);
        }
    }

    // Print on errors
    if (errors == 0)
        printf("Transfer OK — all %u words match\n\r", NUM_WORDS);
    else
        printf("Transfer ERROR — mismatches=%u\n\r", errors);

    return errors;
}

