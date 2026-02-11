// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description: CLINT header file

#ifndef __CLINT_H__
#define __CLINT_H__

#include <stdint.h>
#include "simplyv_conf.h"

// Clint base address
#define CLINT_BASEADDR ((uintptr_t)_peripheral_CLINT_start)

// Clint CSRs
#define CLINT_MSIP      (CLINT_BASEADDR +    0x0u) // Machine mode software interrupt (IPI)
#define CLINT_MTIMECMP  (CLINT_BASEADDR + 0x4000u) // Machine mode timer compare register for Hart 0
#define CLINT_MTIME     (CLINT_BASEADDR + 0xBFF8u) // Timer register

// Initialize CLINT
int clint_init();

// Clean-up CLINT
int clint_clean();

// Read the mtime CSR
uint64_t clint_get_mtime();

// Get the mtimecmp CSR
uint64_t clint_get_mtimecmp();

// Set the mtimecmp CSR
uint64_t clint_set_mtimecmp();

// Sleep for a num_ticks number of ticks
void clint_sleep_ticks (uint64_t ticks);

#endif // __CLINT_H__
