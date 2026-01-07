// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  This file defines the API to adoperate the Timer

#ifndef TIM_H
#define TIM_H

#include <stdint.h>
#include "uninasoc_conf.h"

// https://docs.amd.com/v/u/en-US/pg079-axi-timer
// Base address
#define TIM0_BASEADDR ((uintptr_t)_peripheral_TIM0_start)
#define TIM1_BASEADDR ((uintptr_t)_peripheral_TIM1_start)

// The timer keeps reloading the initial counter value
#define TIM_RELOAD_AUTO 0
// The timer mantains the termination value
#define TIM_RELOAD_HOLD 1

// The timer counts from the specified counter value to 0
#define TIM_COUNT_DOWN 0
// The timer counts from 0 to the specified value
#define TIM_COUNT_UP 1

typedef struct {
    uintptr_t base_addr;
    uint32_t counter;
    uint32_t reload_mode : 1;
    uint32_t count_direction : 1;
} xlnx_tim_t;

// All the Functions return UNINASOC_ERROR in case of error and UNINASOC_OK otherwise

// Initialize timer peripheral
int xlnx_tim_init(xlnx_tim_t* timer);

// Configure the timer
// base_addr should contain the base address of the specific timer
// (TIM0_BASEADDR) and (TIM1_BASEADDR)
// and the other parameters should contain the values specified from the above macros
// in case mode parameters are missing or wrong, the timer will be configured
// COUNT UP and RELOAD HOLD
int xlnx_tim_configure(xlnx_tim_t* timer);

// Enables the timer interrupts
int xlnx_tim_enable_int(xlnx_tim_t* timer);

// Clears the timer interrupt signal, this function is supposed to be used
// to assert the completition of the timer interrupt handling
int xlnx_tim_clear_int(xlnx_tim_t* timer);

// This function starts the timer
int xlnx_tim_start(xlnx_tim_t* timer);

#endif
