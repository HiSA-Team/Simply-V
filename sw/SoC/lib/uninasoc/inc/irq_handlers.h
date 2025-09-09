// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description: 
//  This file defines weak interrupt handlers with a default behaviour (irq_handlers.c)
//  that are supposed to be redefined by the user in order to create custom interrupt handlers
//  (use the __irq_handler__ as seen below to when redefining the functions)

#ifndef INTERRUPTS_H
#define INTERRUPTS_H

#include <stdint.h>

// Interrupt Handlers
// Unlike conventional functions, handlers must have a distinct compiler-generated prologue
// (to save all interrupted context registers) and epilogue (using mret instead of ret).
// Alternatively, the "naked" attribute can be used instead of "interrupt", but this approach is
// less safe and requires carefully crafted assembly code.

// the "__irq_handler__" symbol must be used to redefine the handler correctly inside the specific example
// (see interrupts example)
// NOTE: Since these handlers are accessed with jump instructions inside the vector table, we're assuming that
// the linker won't relocate them over the maximum PC-relative address that the RISC-V jump is able to encode
// [PC - 2^19, PC + 2^19 - 1]

#define __irq_handler__ __attribute__((interrupt("machine")))

__attribute__((weak)) void _sw_handler(void) __irq_handler__;
__attribute__((weak)) void _timer_handler(void) __irq_handler__;
__attribute__((weak)) void _ext_handler(void) __irq_handler__;

#endif
