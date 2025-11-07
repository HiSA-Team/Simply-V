// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  Very simple implementations of PLIC functions used to correctly
//  configure and handle external interrupts


#include "uninasoc.h"
#include "io.h"
#include <stdint.h>

#define MAX_SOURCES 3

// In this example, only 4 interrupts sources are supported in the SoC

static size_t sources = MAX_SOURCES;

int plic_init()
{
    // No-op
    return UNINASOC_OK;
}

void plic_configure(uint32_t* priorities, size_t source_num){

    if(source_num < MAX_SOURCES)
        sources = source_num;

    //Set interrupt priorities
    for (int i = 1; i <= sources; i++) {
        iowrite32(PLIC_BASEADDR + (0x4 * i) , priorities[i]);
    }

}

void plic_enable_all(){

    uint32_t enable = 0;

    for (int i = 1; i <= sources; i++) {
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
