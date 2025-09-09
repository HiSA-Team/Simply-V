// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  This file implements all the Timer's related functions

#include "uninasoc.h"

#ifdef TIM_IS_ENABLED

#include "io.h"
#include <stdint.h>

// TODO47: For now, only timer 0 is used.
//         These APIs need to be extended to work on TIM0, TIM1 and other instances

// Macros used internally, so they're place here instead of the header file

// Registers (both TIM0 and TIM1 have same registers)
#define TIM_CSR 0x0000 // Control and Status register
#define TIM_TLR 0x0004 // Load register

#define TIM_CSR_COUNTER_MODE (1 << 1)
#define TIM_CSR_RELOAD_MODE (1 << 4)
#define TIM_CSR_LOAD (1 << 5)
#define TIM_CSR_ENABLE_INTERRUPT (1 << 6)
#define TIM_CSR_ENABLE (1 << 7)
#define TIM_CSR_INTERRUPT (1 << 8)

// Extend this function implementation in case you add more peripherals
static inline int xlnx_tim_assert(xlnx_tim_t* timer)
{
    if ((timer->base_addr != TIM0_BASEADDR) && (timer->base_addr != TIM1_BASEADDR)) {
        return UNINASOC_ERROR;
    }
    return UNINASOC_OK;
}


int xlnx_tim_init(xlnx_tim_t* timer)
{
    // No-op
    return UNINASOC_OK;
}

int xlnx_tim_configure(xlnx_tim_t* timer)
{
    if (xlnx_tim_assert(timer) != UNINASOC_OK) {
        return UNINASOC_ERROR;
    }

    uintptr_t tim_tlr = (uintptr_t)(timer->base_addr + TIM_TLR);
    uintptr_t tim_csr = (uintptr_t)(timer->base_addr + TIM_CSR);
    // reset to default UP COUNT and HOLD
    uint32_t config = 0;

    // The configurations are defined as the same bits
    // but 0 or 1 depending on the mode, so need to do
    // bits manipulations
    if (timer->reload_mode == TIM_RELOAD_AUTO)
        config |= TIM_CSR_RELOAD_MODE;
    // if HOLD do nothing

    if (timer->count_direction == TIM_COUNT_DOWN)
        config |= TIM_CSR_COUNTER_MODE;
    // if count UP do nothing

    // Needed by the timer to load the counter value
    config |= TIM_CSR_LOAD;
    // finally configure the peripheral
    iowrite32(tim_tlr, timer->counter);
    iowrite32(tim_csr, config);
    return UNINASOC_OK;
}

int xlnx_tim_enable_int(xlnx_tim_t* timer)
{
    if (xlnx_tim_assert(timer) != UNINASOC_OK) {
        return UNINASOC_ERROR;
    }

    uintptr_t tim_csr = (uintptr_t)(timer->base_addr + TIM_CSR);
    uint32_t csr_value = ioread32(tim_csr);
    csr_value |= TIM_CSR_ENABLE_INTERRUPT;
    iowrite32(tim_csr, csr_value);
    return UNINASOC_OK;
}

int xlnx_tim_clear_int(xlnx_tim_t* timer)
{
    if (xlnx_tim_assert(timer) != UNINASOC_OK) {
        return UNINASOC_ERROR;
    }

    // Clear timer interrupt by setting TCSR0.T0INT
    uintptr_t tim_csr = (uintptr_t)(timer->base_addr + TIM_CSR);
    uint32_t csr_value = ioread32(tim_csr);
    csr_value |= TIM_CSR_INTERRUPT;
    iowrite32(tim_csr, csr_value);
    return UNINASOC_OK;
}

int xlnx_tim_start(xlnx_tim_t* timer)
{
    if (xlnx_tim_assert(timer) != UNINASOC_OK) {
        return UNINASOC_ERROR;
    }

    uintptr_t tim_csr = (uintptr_t)(timer->base_addr + TIM_CSR);
    uint32_t csr_value = ioread32(tim_csr);
    // Lower LOAD0 (necessary to start the timer correctly)
    csr_value &= ~TIM_CSR_LOAD;
    csr_value |= TIM_CSR_ENABLE;
    iowrite32(tim_csr, csr_value);
    return UNINASOC_OK;
}

#endif
