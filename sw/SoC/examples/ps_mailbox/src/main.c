// Author: Federica Sarnataro
// Description:
//   CPU side of the PS <-> Simply-V mailbox test (Zynq profile).
//   1. Clear the mailbox in BRAM_0 and tell the PS it is ready
//   2. Wait for the value written by the PS and print it on UART
//   3. Write back its bitwise NOT for the PS
//   The PS side is sw/host/zynq/ps_mailbox.

#include "simplyv.h"
#include <stdint.h>
#include "ps_mailbox.h"

int main()
{
    // Initialize HAL
    simplyv_init();

    volatile uint32_t * mbox = (volatile uint32_t *)(_peripheral_BRAM_0_start + PS_MAILBOX_OFFSET);
    uint32_t value;

    // Clear the mailbox, then tell the PS that the CPU is ready
    mbox[MBOX_PS_VALUE]  = 0;
    mbox[MBOX_PS_VALID]  = 0;
    mbox[MBOX_CPU_VALUE] = 0;
    mbox[MBOX_CPU_VALID] = 0;
    __asm__ volatile ("fence" ::: "memory");
    mbox[MBOX_CPU_READY] = MBOX_MAGIC_CPU_READY;

    printf("[CPU] Mailbox at 0x%08x, waiting for the PS\n\r", (uint32_t)(uintptr_t)mbox);

    // Wait for the PS value
    while ( mbox[MBOX_PS_VALID] != MBOX_MAGIC_VALID );
    __asm__ volatile ("fence" ::: "memory");
    value = mbox[MBOX_PS_VALUE];
    printf("[CPU] Read from the PS: 0x%08x\n\r", value);

    // Answer with the bitwise NOT
    mbox[MBOX_CPU_VALUE] = ~value;
    __asm__ volatile ("fence" ::: "memory");
    mbox[MBOX_CPU_VALID] = MBOX_MAGIC_VALID;
    printf("[CPU] Wrote to the PS: 0x%08x\n\r", ~value);

    // Return to caller
    return SIMPLYV_OK;
}
