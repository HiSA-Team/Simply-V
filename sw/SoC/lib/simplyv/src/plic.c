// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
//  Very simple implementations of PLIC functions used to correctly
//  configure and handle external interrupts


#include "simplyv.h"
#include "io.h"
#include <stdint.h>

// Number of configured sources
static size_t sources = PLIC_MAX_SOURCES;

int plic_init()
{
    // Enable MIE.MEIE (Machine External Interrupt)
    uint32_t mask = MIE_MEIE_MASK;
    asm volatile("csrs  mie, %0": "=r" (mask));

    // Reset priorities
    for (unsigned id = 1; id <= 31; ++id){
        iowrite32(PLIC_PRIO_SRC(id), 0u);
    }

    // Drain pending interrupts
    while (1) {
        uint32_t id = ioread32(PLIC_CLAIM_CTX0);
        if (id == 0) break;
        iowrite32(PLIC_COMPLETE_CTX0, id);
    }

    // Reset registers
    iowrite32(PLIC_THRESHOLD_CTX0, 0u);
    iowrite32(PLIC_INT_ENABLE_CTX0, 0x00000000u);

    return SIMPLYV_OK;
}

int plic_clean ()
{
    // Clear MIE.MEIE (Machine External Interrupt)
    uint32_t mask = MIE_MEIE_MASK;
    asm volatile("csrc  mie, %0": "=r" (mask));

    return SIMPLYV_OK;
}

// Configure a single line
void plic_configure_set_one(uint32_t priority, size_t source){
    iowrite32(PLIC_BASEADDR + (0x4 * source) , priority);
}

// Configure a contiguous set of interrupt sources
int plic_configure_set_array(uint32_t* priorities, size_t source_num){

    if(source_num > PLIC_MAX_SOURCES)
        return SIMPLYV_ERROR;

    // Set interrupt priorities
    // Skip reserved line zero
    for (int i = 1; i <= source_num; i++) {
        plic_configure_set_one(priorities[i], i);
    }

    return SIMPLYV_OK;

}

void plic_enable_all(){

    uint32_t enable = 0;

    for (int i = 1; i <= PLIC_MAX_SOURCES; i++) {
        // bits 0-31 represent sources 0-31, so
        // for example to enable the peripherals from 1 to 3
        // must write powers of 2 with exponents from 1 to 3
        enable += (1 << i);
    }
    iowrite32(PLIC_INT_ENABLE_CTX0 , enable);
}

uint32_t plic_claim(){
    return ioread32(PLIC_CLAIM_CTX0);
}

void plic_complete(uint32_t interrupt_id){
    iowrite32(PLIC_COMPLETE_CTX0, interrupt_id);
}
