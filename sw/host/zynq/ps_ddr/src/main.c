// PS side of the PS DDR test (Zynq profile, point 3b).
// The Simply-V CPU reaches the DDR of the PS through the PS slave port S_AXI_GP0, at the
// same addresses seen by the PS (MBUS range PSDDR). The PS prints the result on its UART.
// The DDR is cached by the Cortex-A9, while the CPU accesses it directly: the PS flushes
// the lines it writes and invalidates the lines written by the CPU before reading them.
// The CPU side is sw/SoC/examples/ps_ddr.
#include <stdint.h>
#include "xil_printf.h"
#include "xil_cache.h"
#include "xpseudo_asm.h"
#include "simplyv_conf.h"
#include "ps_ddr.h"

// Wait for a flag written by the CPU, reading it again from the DDR each time.
// No timeout: the CPU can be loaded after the PS
static void wait_for(volatile uint32_t *shm, uint32_t word, uint32_t magic)
{
    do {
        Xil_DCacheInvalidateRange((INTPTR)&shm[word], sizeof(uint32_t));
    } while (shm[word] != magic);
}

int main(void)
{
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
    Xil_DCacheFlushRange((INTPTR)&shm[PS_DDR_PS_DATA], PS_DDR_NUM_DATA * sizeof(uint32_t));
    dsb();
    shm[PS_DDR_PS_VALID] = PS_DDR_MAGIC_VALID;
    Xil_DCacheFlushRange((INTPTR)&shm[PS_DDR_PS_VALID], sizeof(uint32_t));
    xil_printf("[PS] Wrote %u words to the DDR\r\n", PS_DDR_NUM_DATA);

    // 3. Wait for the CPU answer, read it again from the DDR and check it
    wait_for(shm, PS_DDR_CPU_VALID, PS_DDR_MAGIC_VALID);
    Xil_DCacheInvalidateRange((INTPTR)&shm[PS_DDR_CPU_DATA], PS_DDR_NUM_DATA * sizeof(uint32_t));
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
