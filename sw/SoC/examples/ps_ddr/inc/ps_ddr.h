// Author: Federica Sarnataro
// Description:
//   Shared area in the DDR of the Zynq-7000 PS, between the PS and the Simply-V CPU.
//   Used by sw/SoC/examples/ps_ddr (CPU side) and sw/host/zynq/ps_ddr (PS side).
//   Both sides see it at _peripheral_PSDDR_start: the MBUS range PSDDR has the same
//   addresses as the PS DDR, reached through the PS slave port S_AXI_GP0.
//   The words written by the CPU and the ones written by the PS are in different
//   cache lines (32 bytes on the Cortex-A9), so that the PS can invalidate the CPU
//   lines without losing its own writes.

#ifndef PS_DDR_H
#define PS_DDR_H

// Number of 32-bit test words in each direction
#define PS_DDR_NUM_DATA         (8u)

// Word offsets from _peripheral_PSDDR_start
enum {
    // Cache lines 0-1: written by the CPU
    PS_DDR_CPU_READY = 0,   // CPU: area cleared, waiting for the PS
    PS_DDR_CPU_VALID = 1,   // CPU: PS_DDR_CPU_DATA is valid
    PS_DDR_CPU_DATA  = 8,   // CPU: bitwise NOT of the PS words (8 words)
    // Cache lines 2-3: written by the PS
    PS_DDR_PS_VALID  = 16,  // PS : PS_DDR_PS_DATA is valid
    PS_DDR_PS_DATA   = 24,  // PS : test words (8 words)
    PS_DDR_NUM_WORDS = 32
};

// Magic values for the flags
#define PS_DDR_MAGIC_CPU_READY  (0x52454459u) // "REDY"
#define PS_DDR_MAGIC_VALID      (0x56414c44u) // "VALD"

// Test word i written by the PS
#define PS_DDR_PS_WORD(i)       (0xA5A50000u + (i))

#endif // PS_DDR_H
