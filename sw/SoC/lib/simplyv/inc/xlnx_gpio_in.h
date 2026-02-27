// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  This file defines the API to adoperate the Xilinx Input GPIO
// Reference:https://docs.amd.com/v/u/en-US/pg144-axi-gpio

#ifndef _XLNX_GPIO_IN_H
#define _XLNX_GPIO_IN_H

#include <stdint.h>
#include "simplyv_conf.h"

// Registers
// GPIO is configured to use just one channel (so all the "2" registers like GPIO2_DATA are unused)
#define GPIO_DATA  (0x0000u) // Data Register
#define GPIO_TRI   (0x0004u) // Direction Register
#define GPIO2_DATA (0x0008u) // Data register second channel
#define GPIO2_TRI  (0x000Cu) // Data register second channel
#define GIER       (0x011Cu) // Global Interrupt Enable Register
#define IP_ISR     (0x0120u) // Interrupt Status Register
#define IP_IER     (0x0128u) // Interrupt Enable Register

// INTERRUPTS
typedef enum {
    DISABLE_INT = 0,
    ENABLE_INT = 1,
} xlnx_gpio_in_interrupt_conf_t;

// Need to be initialized with _peripheral_GPIOIN_start
typedef struct {
    uintptr_t base_addr;
    xlnx_gpio_in_interrupt_conf_t interrupt;
} xlnx_gpio_in_t;


//All the Functions return SIMPLYV_ERROR in case of error and SIMPLYV_OK otherwise

// Initialize the input gpio and choose to enable or disable interrupts
// if left unspecified as default interrupt are disabled
int xlnx_gpio_in_init(xlnx_gpio_in_t* gpio_in);

// Function that clears the gpio input interrupt bit, effectively signaling the completition
// of interrupt handling
// It's supposed to be used inside Input GPIO's interrupt handler
int xlnx_gpio_in_clear_int(xlnx_gpio_in_t* gpio_in);

// This function returns the content of the Input GPIO's register, used to read input data
int xlnx_gpio_in_read(xlnx_gpio_in_t* gpio_in, uint16_t* data);

#endif // _XLNX_GPIO_IN_H
