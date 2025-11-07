// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  Simple wrapper functions for direct memory I/O

#ifndef IO_H
#define IO_H

#include <stdint.h>

static inline void iowrite32(uintptr_t addr, uint32_t val)
{
    volatile uint32_t* LocalAddr = (volatile uint32_t*)addr;
    *LocalAddr = val;
}

static inline void iowrite16(uintptr_t addr, uint16_t val)
{
    volatile uint16_t* LocalAddr = (volatile uint16_t*)addr;
    *LocalAddr = val;
}

static inline void iowrite8(uintptr_t addr, uint8_t val)
{
    volatile uint8_t* LocalAddr = (volatile uint8_t*)addr;
    *LocalAddr = val;
}

static inline uint32_t ioread32(uintptr_t addr)
{
    return *(volatile uint32_t*)addr;
}

static inline uint16_t ioread16(uintptr_t addr)
{
    return *(volatile uint16_t*)addr;
}

static inline uint8_t ioread8(uintptr_t addr)
{
    return *(volatile uint8_t*)addr;
}

#endif
