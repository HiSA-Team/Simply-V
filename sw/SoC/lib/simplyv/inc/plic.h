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
#include "simplyv_conf.h"

// Base address
#define PLIC_BASEADDR ((uintptr_t)_peripheral_PLIC_start)

// Registers
#define PLIC_INT_ENABLE_CTX0    (PLIC_BASEADDR +  0x2000)
#define PLIC_PENDING_BASE       (PLIC_BASEADDR + 0x1000u)
#define PLIC_THRESHOLD_CTX0     (PLIC_BASEADDR + 0x200000)
#define PLIC_CLAIM_CTX0         (PLIC_BASEADDR + 0x200004)
#define PLIC_COMPLETE_CTX0      (PLIC_BASEADDR + 0x200004)

// Functions
#define PLIC_PRIO_SRC(n)      (PLIC_BASEADDR + 4u * (n))

// Intrrupt IDs
// TODO154: this is static for now, must generate by config
#define PLIC_RESERVED_INTERRUPT  0 // PLIC line 0 is reserved
#define PLIC_GPIOIN_INTERRUPT    1 // GPIO In (From PBUS)[embedded only]
#define PLIC_TIM0_INTERRUPT      2 // Timer 0 (From PBUS)
#define PLIC_TIM1_INTERRUPT      3 // Timer 1 (From PBUS)
#define PLIC_UART_INTERRUPT      4 // UART    (From PBUS)
#define PLIC_HLS_INTERRUPT       5 // HLS     (From HLS core) [HPC only]
#define PLIC_CDMA_INTERRUPT      6 // CDMA    (From DMA IP)

// TODO: import from config
// Maximum number of interrupt sources, including reserved line 0
#define PLIC_MAX_SOURCES 6

// Initialize PLIC peripheral
int plic_init();

// This function configures the priorities associated to each peripheral
// "priorities" is an array of size "source_num" containing
// the priority values to assign to each peripherals in order
void plic_configure_set_array(uint32_t* priorities, size_t source_num);
// Configure a single line
void plic_configure_set_one(uint32_t priority, size_t source);

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
