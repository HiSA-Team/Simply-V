// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  Basic "placeholder" implementations of interrupt handlers, supposed
//  to be redefined by the user

#include "uninasoc.h"

void _sw_handler(void) {
    // Unused for this example
}

void _timer_handler(void) {
    // Unused for this example
}

void _ext_handler(void) {
    // Interrupts are automatically disabled by the microarchitecture.
    // Nested interrupts can be enabled manually by setting the IE bit in the mstatus register,
    // but this requires careful handling of registers.
    // Interrupts are automatically re-enabled by the microarchitecture when the MRET instruction is executed.

    // In this example, the core is connected to PLIC target 1 line.
    // Therefore, we need to access the PLIC claim/complete register 1 (base_addr + 0x200004).
    // The interrupt source ID is obtained from the claim register.
    uint32_t interrupt_id = plic_claim();
    switch(interrupt_id){
        case 0x0: // unused
            break;
        case 0x1:
        #ifdef IS_EMBEDDED
            // Not implemented, just clear to continue
            //xlnx_gpio_in_clear_int();
        #endif
        break;
        case 0x2:
            // Not implemented, just clear to continue
            //xlnx_tim_clear_int();
            break;
        default:
            break;
    }

    // To notify the handler completion, a write-back on the claim/complete register is required.
    plic_complete(interrupt_id);
}
