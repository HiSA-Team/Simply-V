// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
//  Simple implementations of CLINT functions to configure and
//          handle timer interrupts and mtime CSR


#include "simplyv.h"
#include "io.h"
#include <stdint.h>

// MIE.MTIE CSR mask
#define MIE_MTIE_MASK (0x0080u)

int clint_init()
{
    // Enable MIE.MTIE (Machine Timer Interrupt)
    asm volatile("li    t0 ,  %0" :: "i"(MIE_MTIE_MASK));
    asm volatile("csrs  mie, t1");

    // Reset priorities

    // Drain pending interrupts

    // Reset registers

    return SIMPLYV_OK;
}

int clint_clean ()
{
    // Clear MIE.MTIE (Machine Timer Interrupt)
    asm volatile("li    t0 ,  %0" :: "i"(MIE_MTIE_MASK));
    asm volatile("csrc  mie, t1");

    return SIMPLYV_OK;
}