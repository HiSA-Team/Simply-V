// Author: Federica Sarnataro
// Description:
//   CPU side of the PS DDR test (Zynq profile, point 3b): the Simply-V CPU reads and
//   writes the DDR of the PS through the MBUS range PSDDR and the PS slave port S_AXI_GP0.
//   1. Clear the shared area in the PS DDR and tell the PS it is ready
//   2. Wait for the PS words, check them and print them on UART
//   3. Write back their bitwise NOT for the PS
//   The PS side is sw/host/zynq/ps_ddr.

#include "simplyv.h"
#include <stdint.h>
#include "ps_ddr.h"

int main()
{
    // Initialize HAL
    simplyv_init();

    volatile uint32_t * shm = (volatile uint32_t *)(_peripheral_PSDDR_start);
    uint32_t value;
    uint32_t errors = 0;

    // Clear the shared area, then tell the PS that the CPU is ready
    for ( uint32_t i = 0; i < PS_DDR_NUM_WORDS; i++ ) {
        shm[i] = 0;
    }
    __asm__ volatile ("fence" ::: "memory");
    shm[PS_DDR_CPU_READY] = PS_DDR_MAGIC_CPU_READY;

    printf("[CPU] Shared area in the PS DDR at 0x%08x, waiting for the PS\n\r", (uint32_t)(uintptr_t)shm);

    // Wait for the PS words, check and print them
    while ( shm[PS_DDR_PS_VALID] != PS_DDR_MAGIC_VALID );
    __asm__ volatile ("fence" ::: "memory");
    for ( uint32_t i = 0; i < PS_DDR_NUM_DATA; i++ ) {
        value = shm[PS_DDR_PS_DATA + i];
        printf("[CPU] Read from the PS DDR [%u]: 0x%08x\n\r", i, value);
        if ( value != PS_DDR_PS_WORD(i) ) {
            errors++;
        }
        shm[PS_DDR_CPU_DATA + i] = ~value;
    }

    // Tell the PS that the answer is ready
    __asm__ volatile ("fence" ::: "memory");
    shm[PS_DDR_CPU_VALID] = PS_DDR_MAGIC_VALID;

    if ( errors == 0 ) {
        printf("[CPU] PS words OK, wrote back their bitwise NOT\n\r");
    }
    else {
        printf("[CPU] ERROR: %u wrong PS words\n\r", errors);
    }

    // Return to caller
    return SIMPLYV_OK;
}
