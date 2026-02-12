// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
//  Simple implementations of CLINT functions to configure and
//          handle timer interrupts and mtime CSR


#include "simplyv.h"
#include "io.h"
#include <stdint.h>

// Define CLINT frequency in MHz
// TODO: import from config
#ifdef IS_EMBEDDED
    #define CLINT_FREQ_MHz (20u)
#else
    #define CLINT_FREQ_MHz (100u)
#endif


// MIE.MTIE CSR mask
#define MIE_MTIE_MASK (0x0080u)

int clint_init()
{
    // Clear MIE.MTIE (Machine Timer Interrupt)
    uint32_t mask = MIE_MTIE_MASK;
    asm volatile("csrc  mie, %0": "=r" (mask));

    // Drain pending interrupts by writing to mtimecmp
    clint_set_mtimecmp( 0 );

    return SIMPLYV_OK;
}

int clint_disable()
{
    // Clear MIE.MTIE (Machine Timer Interrupt)
    uint32_t mask = MIE_MTIE_MASK;
    asm volatile("csrc  mie, %0": "=r" (mask));

    return SIMPLYV_OK;
}

int clint_enable( uint32_t mtimecmp ) {

    // Set mtimecmp CSR
    int retval = clint_set_mtimecmp( mtimecmp );
    if ( retval != SIMPLYV_OK ) {
        return retval;
    }

    // Enable MIE.MTIE (Machine Timer Interrupt)
    uint32_t mask = MIE_MTIE_MASK;
    asm volatile("csrs  mie, %0": "=r" (mask));

    return SIMPLYV_OK;
}

// Read the mtime CSR
uint32_t clint_get_mtime()
{
    return ioread32(CLINT_MTIME);
}

// Get the mtimecmp CSR
uint32_t clint_get_mtimecmp()
{
    return ioread32(CLINT_MTIMECMP);
}

// Set the mtimecmp CSR
int clint_set_mtimecmp( uint32_t value )
{
    iowrite32(CLINT_MTIMECMP, value );
    return SIMPLYV_OK;
}

// Sleep for a num_ticks number of ticks
int clint_sleep_ticks( uint32_t ticks )
{
    int retval;

    // Prepare mtimecmp value
    uint32_t time_read_value = clint_get_mtime();
    uint32_t mtimecmp_write_value = time_read_value + ticks;

    // DEBUG
    printf("%s:%d ticks                %u\n\r", __FILE__, __LINE__, ticks);
    printf("%s:%d mtime_read_value     %u\n\r", __FILE__, __LINE__, time_read_value);
    printf("%s:%d mtimecmp_write_value %u\n\r", __FILE__, __LINE__, mtimecmp_write_value);

    // Enable CLINT
    retval = clint_enable( mtimecmp_write_value );
    if ( retval != SIMPLYV_OK ) {
        return retval;
    }

    // Wait for interrupt
    asm volatile("wfi");

    // Disable CLINT
    retval = clint_disable();
    if ( retval != SIMPLYV_OK ) {
        return retval;
    }

    return SIMPLYV_OK;
}

// Sleep for milliseconds
int clint_sleep_us( uint32_t usec )
{

    // Compute number of ticks based on frequency
    return clint_sleep_ticks ( usec / CLINT_FREQ_MHz );
}