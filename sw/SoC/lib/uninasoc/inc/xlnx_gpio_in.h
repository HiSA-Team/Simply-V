// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  This file defines the API to adoperate the Input GPIO

#ifndef XLNX_GPIO_IN_H
#define XLNX_GPIO_IN_H

#include <stdint.h>

// https://docs.amd.com/v/u/en-US/pg144-axi-gpio

// Import linker script symbol
extern const volatile uint32_t _peripheral_GPIO_in_start;

#define GPIO_IN_BASEADDR ((uintptr_t)&_peripheral_GPIO_in_start)

// INTERRUPTS
typedef enum {
    DISABLE_INT = 0,
    ENABLE_INT = 1,
} xlnx_gpio_in_interrupt_conf_t;

// Need to be initialized with GPIO_IN_BASEADDR
typedef struct {
    uintptr_t base_addr;
    xlnx_gpio_in_interrupt_conf_t interrupt;
} xlnx_gpio_in_t;


//All the Functions return UNINASOC_ERROR in case of error and UNINASOC_OK otherwise

// Initialize the input gpio and choose to enable or disable interrupts
// if left unspecified as default interrupt are disabled
int xlnx_gpio_in_init(xlnx_gpio_in_t* gpio_in);

// Function that clears the gpio input interrupt bit, effectively signaling the completition
// of interrupt handling
// It's supposed to be used inside Input GPIO's interrupt handler
int xlnx_gpio_in_clear_int(xlnx_gpio_in_t* gpio_in);

// This function returns the content of the Input GPIO's register, used to read input data
int xlnx_gpio_in_read(xlnx_gpio_in_t* gpio_in, uint16_t* data);

#endif
