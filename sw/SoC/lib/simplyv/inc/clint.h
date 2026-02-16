// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description: CLINT header file

#ifndef __CLINT_H__
#define __CLINT_H__

#include <stdint.h>
#include "simplyv_conf.h"

// Use wfi instruction to sychronize
// NOTE: This breaks in case of other interrupts, e.g. from PLIC or ebreak (GDB)
// NOTE: if not defined, use global synchronization flag
// #define CLINT_USE_WFI

// Clint base address
#define CLINT_BASEADDR ((uintptr_t)_peripheral_CLINT_start)

// Clint CSRs offsets
#define CLINT_MSIP           (CLINT_BASEADDR +    0x0u) // Machine mode software interrupt (IPI)
#define CLINT_MTIMECMP       (CLINT_BASEADDR + 0x4000u) // Machine mode timer compare register for Hart 0
#define CLINT_MTIME          (CLINT_BASEADDR + 0xBFF8u) // Timer register

// Define CLINT frequency in MHz
// TODO198: import from config
//       for now we use the default frequency of the MBUS
#ifdef IS_EMBEDDED
    #define CLINT_FREQ_MHz (20u)
#else
    #define CLINT_FREQ_MHz (100u)
#endif

// Divide factor for RTC w.r.t. MBUS clock
// NOTE: this must be aligned with clint custom_top_wrapper.sv
#define RTC_CLOCK_DIVIDE (20u)
// Frequecy of real-time clock in MHz
#define RTC_FREQ_MHz (CLINT_FREQ_MHz / RTC_CLOCK_DIVIDE)

// Simple flag to sync _timer_handler and clint_sleep_ticks()
extern uint32_t _timer_handler_flag;

// Initialize CLINT
int clint_init();

// Clean-up CLINT
int clint_disable();

// Enable CLINT with mtimecmp value
int clint_enable( uint32_t mtimecmp );

// Read the mtime CSR
uint32_t clint_get_mtime();

// Get the mtimecmp CSR
uint32_t clint_get_mtimecmp();

// Set the mtimecmp CSR
int clint_set_mtimecmp( uint32_t value );

// Sleep for a num_ticks number of ticks
int clint_sleep_ticks( uint32_t ticks );

// Sleep for microseconds
int clint_sleep_us( uint32_t millisec );

#endif // __CLINT_H__
