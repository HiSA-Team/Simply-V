// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  This file defines the API to adoperate the PLIC (Platform-Level Interrupt Controller)
//  in order to manage external interrupts

#ifndef PLIC_H
#define PLIC_H

#include <stddef.h>
#include <stdint.h>
#include "uninasoc_conf.h"

// Base address
#define PLIC_BASEADDR ((uintptr_t)_peripheral_PLIC_start)

// Registers
#define PLIC_INT_ENABLE_CTX0    (PLIC_BASEADDR +   0x2000)
#define PLIC_CLAIM_CTX0         (PLIC_BASEADDR + 0x200004)
#define PLIC_COMPLETE_CTX0      (PLIC_BASEADDR + 0x200004)

// Functions

// Initialize PLIC peripheral
int plic_init();

// This function configures the priorities associated to each peripheral
// "priorities" is an array of size "source_num" containing
// the priority values to assign to each peripherals in order
void plic_configure(uint32_t* priorities, size_t source_num);

// This function enables the interrupts of each external peripheral
void plic_enable_all();

// This function is used to claim the interrupt, the processor will obtain
// the ID associated to the interrupting peripheral
// It's supposed to be used inside the external interrupts handler
uint32_t plic_claim();

// This function is used to signal the completition of the routine associated
// to the raised interrupt
// It's supposed to be used inside the external interrupts handler
void plic_complete(uint32_t interrupt_id);

#endif
