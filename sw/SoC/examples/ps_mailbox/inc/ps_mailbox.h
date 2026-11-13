// Author: Federica Sarnataro
// Description:
//   Mailbox shared between the Zynq-7000 PS and the Simply-V CPU, in BRAM_0.
//   Used by sw/SoC/examples/ps_mailbox (CPU side) and sw/host/zynq/ps_mailbox (PS side).
//   The CPU sees it at _peripheral_BRAM_0_start + PS_MAILBOX_OFFSET, the PS adds the
//   base of its M_AXI_GP0 window (0x4000_0000).
//   The offset is in the middle of BRAM_0: below the stack (top of BRAM_0) and above
//   the program (a few KB from the bottom of BRAM_0).

#ifndef PS_MAILBOX_H
#define PS_MAILBOX_H

// Offset of the mailbox from the base of BRAM_0
#define PS_MAILBOX_OFFSET       (0x8000u)

// Mailbox words (32-bit), in order
enum {
    MBOX_CPU_READY = 0, // CPU: mailbox cleared, waiting for the PS
    MBOX_PS_VALUE,      // PS : value for the CPU
    MBOX_PS_VALID,      // PS : MBOX_PS_VALUE is valid
    MBOX_CPU_VALUE,     // CPU: value for the PS (bitwise NOT of MBOX_PS_VALUE)
    MBOX_CPU_VALID,     // CPU: MBOX_CPU_VALUE is valid
    MBOX_NUM_WORDS
};

// Magic values for the flags
#define MBOX_MAGIC_CPU_READY    (0x52454459u) // "REDY"
#define MBOX_MAGIC_VALID        (0x56414c44u) // "VALD"

// Value written by the PS
#define MBOX_PS_TEST_VALUE      (0xCAFE0123u)

#endif // PS_MAILBOX_H
