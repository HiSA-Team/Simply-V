// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
//  Simple implementations of CLINT functions to configure and
//          handle timer interrupts and mtime CSR


#include "simplyv.h"


#ifdef CLINT_IS_ENABLED

#include "io.h"
#include <stdint.h>

int clint_init()
{
    // Clear MIE.MTIE (Machine Timer Interrupt)
    uint32_t mask = MIE_MTIE_MASK;
    asm volatile("csrc  mie, %0": "=r" (mask));

    // Drain pending interrupts by writing to mtimecmp
    clint_set_mtimecmp( (uint64_t)0 );

    return SIMPLYV_OK;
}

int clint_disable()
{
    // Clear MIE.MTIE (Machine Timer Interrupt)
    uint32_t mask = MIE_MTIE_MASK;
    asm volatile("csrc  mie, %0": "=r" (mask));

    return SIMPLYV_OK;
}

void clint_enable( uint64_t mtimecmp ) {

    // Set mtimecmp CSR
    clint_set_mtimecmp( mtimecmp );

    // Enable MIE.MTIE (Machine Timer Interrupt)
    uint32_t mask = MIE_MTIE_MASK;
    asm volatile("csrs  mie, %0": "=r" (mask));
}

// Read the mtime CSR
uint64_t clint_get_mtime()
{
    // MTIME is 64 bits regardless of XLEN
    return ioread64(CLINT_MTIME);
}

// Get the mtimecmp CSR
uint64_t clint_get_mtimecmp()
{
    // MTIMECMP is 64 bits regardless of XLEN
    return ioread64(CLINT_MTIMECMP);
}

// Set the mtimecmp CSR
void clint_set_mtimecmp( uint64_t value )
{
    // MTIMECMP is 64 bits regardless of XLEN
    #ifdef __LP64__
        return iowrite64(CLINT_MTIMECMP, value);
    #else
        // For RV32, we can't just use iowrite64().
        // We use the RV32 sample code from RISC-V spec (3.2.1. Machine Timer Registers (mtime and mtimecmp))
        // to avoid spurious timer interrupts during mtimecmp setup.
        iowrite32(CLINT_MTIMECMP   , -1);                      // No smaller than old value.
        iowrite32(CLINT_MTIMECMP +4, (uint32_t)(value >> 32)); // No smaller than new value
        iowrite32(CLINT_MTIMECMP   , (uint32_t)value);         // New value
    #endif
}

// Sleep for a num_ticks number of ticks
int clint_sleep_ticks( uint64_t ticks )
{
    int retval;

    // Prepare mtimecmp value
    uint64_t mtime_read_value = clint_get_mtime();
    uint64_t mtimecmp_write_value = mtime_read_value + ticks;

    // Enable CLINT
    clint_enable( mtimecmp_write_value );

#ifdef CLINT_USE_WFI
    // Wait for interrupt (wait for any other interrupts, not only timer's, e.g. PLIC or ebreak (GDB))
    asm volatile("wfi");
#else // ! defined(CLINT_USE_WFI)
    // Spin on flag
    // NOTE: this is a simple solution, used for demonstration with
    //       those cores that do not support the A extention
    // TODO: use atomics to sync with _timer_handler
    _timer_handler_flag = 0;
    while ( _timer_handler_flag != 1 );
#endif // ! defined(CLINT_USE_WFI)

    return SIMPLYV_OK;
}

// Sleep for microseconds
int clint_sleep_us( uint32_t usec )
{
    // Compute number of ticks based on RTC frequency
    return clint_sleep_ticks ( (uint64_t)(usec * RTC_FREQ_MHz) );
}

#endif // CLINT_IS_ENABLED