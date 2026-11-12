// PS side of the PS DDR test (Zynq profile, point 3b).
// The Simply-V CPU reaches the DDR of the PS through the PS slave port S_AXI_GP0, at the
// same addresses seen by the PS (MBUS range PSDDR). The PS prints the result on its UART.
// The DDR is cached by the Cortex-A9, while the CPU accesses it directly: the PS makes
// the shared area not cacheable before using it.
// The CPU side is sw/SoC/examples/ps_ddr.
#include <stdint.h>
#include "xil_printf.h"
#include "xil_mmu.h"
#include "simplyv_conf.h"
#include "ps_ddr.h"

// Wait for a flag written by the CPU, reading it again from the DDR each time.
// No timeout: the CPU can be loaded after the PS
static void wait_for(volatile uint32_t *shm, uint32_t word, uint32_t magic)
{
    while (shm[word] != magic);
}

int main(void)
{
    // Shared area not cacheable for the PS (1 MB MMU section): the CPU reaches the DDR
    // without passing through the PS caches
    Xil_SetTlbAttributes((INTPTR)_peripheral_PSDDR_start, NORM_NONCACHE);

    volatile uint32_t *shm = (volatile uint32_t *)(uintptr_t)(_peripheral_PSDDR_start);
    uint32_t value;
    uint32_t errors = 0;

    xil_printf("[PS] Shared area in the DDR at 0x%08x, waiting for the CPU\r\n", (uint32_t)(uintptr_t)shm);

    // 1. Wait for the CPU
    wait_for(shm, PS_DDR_CPU_READY, PS_DDR_MAGIC_CPU_READY);

    // 2. Write the test words, push them to the DDR, then the flag
    for (uint32_t i = 0; i < PS_DDR_NUM_DATA; i++) {
        shm[PS_DDR_PS_DATA + i] = PS_DDR_PS_WORD(i);
    }
    shm[PS_DDR_PS_VALID] = PS_DDR_MAGIC_VALID;
    xil_printf("[PS] Wrote %u words to the DDR\r\n", PS_DDR_NUM_DATA);

    // 3. Wait for the CPU answer, read it again from the DDR and check it
    wait_for(shm, PS_DDR_CPU_VALID, PS_DDR_MAGIC_VALID);
    for (uint32_t i = 0; i < PS_DDR_NUM_DATA; i++) {
        value = shm[PS_DDR_CPU_DATA + i];
        xil_printf("[PS] Read from the CPU [%u]: 0x%08x\r\n", i, value);
        if (value != ~PS_DDR_PS_WORD(i)) {
            errors++;
        }
    }

    if (errors != 0) {
        xil_printf("[PS] ERROR: %u wrong words\r\n", errors);
        return 1;
    }
    xil_printf("[PS] Test passed\r\n");
    return 0;
}
