// Author: Federica Sarnataro
// Description:
//   PS side of the PS <-> Simply-V mailbox test (Zynq profile, point 3a).
//   The PS reaches the Simply-V MBUS through M_AXI_GP0: PS address 0x4000_0000
//   is MBUS address 0x0 (the top 2 address bits are dropped in sys_master).
//   1. Wait until the CPU has cleared the mailbox in BRAM_0
//   2. Write MBOX_PS_TEST_VALUE for the CPU
//   3. Wait for the CPU answer and check that it is the bitwise NOT
//   The result is written to ps_result (fixed address 0x0011F000), read by XSDB.
//   The CPU side is sw/SoC/examples/ps_mailbox.

#include <stdint.h>
#include "simplyv_conf.h"
#include "ps_mailbox.h"

// Base of the M_AXI_GP0 window, seen from the PS
#define PS_M_AXI_GP0_BASE   (0x40000000u)

// Number of mailbox reads before giving up (each read crosses M_AXI_GP0)
#define TIMEOUT_POLLS       (5000000u)

// Result words
enum {
    RES_STEP = 0,   // Last step reached (STEP_*)
    RES_ERROR,      // ERR_*
    RES_WROTE,      // Value written by the PS
    RES_READ,       // Value read back from the CPU
    RES_NUM_WORDS
};

enum { STEP_START = 1, STEP_CPU_READY, STEP_PS_WROTE, STEP_CPU_ANSWERED, STEP_DONE };
enum { ERR_NONE = 0, ERR_TIMEOUT_CPU_READY, ERR_TIMEOUT_CPU_ANSWER, ERR_WRONG_VALUE };

// Test result, at 0x0011F000 (see ps.ld)
volatile uint32_t ps_result[RES_NUM_WORDS] __attribute__((section(".ps_result")));

static inline void dsb(void)
{
    __asm__ volatile ("dsb" ::: "memory");
}

// Wait until mbox[word] == magic, return 0 on timeout
static int wait_for(volatile uint32_t * mbox, uint32_t word, uint32_t magic)
{
    for ( uint32_t i = 0; i < TIMEOUT_POLLS; i++ ) {
        if ( mbox[word] == magic ) {
            return 1;
        }
    }
    return 0;
}

int main(void)
{
    volatile uint32_t * mbox = (volatile uint32_t *)(uintptr_t)
        (PS_M_AXI_GP0_BASE + _peripheral_BRAM_0_start + PS_MAILBOX_OFFSET);

    ps_result[RES_STEP]  = STEP_START;
    ps_result[RES_ERROR] = ERR_NONE;
    ps_result[RES_WROTE] = 0;
    ps_result[RES_READ]  = 0;

    // 1. Wait for the CPU
    if ( !wait_for(mbox, MBOX_CPU_READY, MBOX_MAGIC_CPU_READY) ) {
        ps_result[RES_ERROR] = ERR_TIMEOUT_CPU_READY;
        return 1;
    }
    ps_result[RES_STEP] = STEP_CPU_READY;

    // 2. Write the value, then the flag
    mbox[MBOX_PS_VALUE] = MBOX_PS_TEST_VALUE;
    dsb();
    mbox[MBOX_PS_VALID] = MBOX_MAGIC_VALID;
    dsb();
    ps_result[RES_WROTE] = MBOX_PS_TEST_VALUE;
    ps_result[RES_STEP]  = STEP_PS_WROTE;

    // 3. Wait for the CPU answer and check it
    if ( !wait_for(mbox, MBOX_CPU_VALID, MBOX_MAGIC_VALID) ) {
        ps_result[RES_ERROR] = ERR_TIMEOUT_CPU_ANSWER;
        return 1;
    }
    ps_result[RES_STEP] = STEP_CPU_ANSWERED;
    ps_result[RES_READ] = mbox[MBOX_CPU_VALUE];

    if ( ps_result[RES_READ] != ~MBOX_PS_TEST_VALUE ) {
        ps_result[RES_ERROR] = ERR_WRONG_VALUE;
        return 1;
    }

    ps_result[RES_STEP] = STEP_DONE;
    return 0;
}
