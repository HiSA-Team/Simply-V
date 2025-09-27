// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  This file implements all the Input GPIO's related functions

#include "uninasoc.h"

// #ifdef IS_EMBEDDED // TODO47: placeholder to HAL

#ifdef GPIO_IN_IS_ENABLED
#include "io.h"
#include <stdint.h>

// GPIO is configured to use just one channel (so all the "2" registers like GPIO2_DATA are unused)
// Bits

#define GPIO_IN_DATA 0x0000 // Data Register
#define GPIO_IN_TRI 0x0004 // Direction Register
#define GPIO2_IN_DATA 0x0008 // Data register second channel
#define GPIO2_IN_TRI 0x000C // Data register second channel
#define GPIO_IN_GIER 0x011C // Global Interrupt Enable Register
#define GPIO_IN_ISR 0x0120 // Interrupt Status Register
#define GPIO_IN_IER 0x0128 // Interrupt Enable Register

// Extend this function implementation in case you add more peripherals
static inline int assert_gpio_in(xlnx_gpio_in_t* gpio)
{
    if ((gpio->base_addr != GPIO_IN_BASEADDR)) {
        return UNINASOC_ERROR;
    }
    return UNINASOC_OK;
}

int xlnx_gpio_in_init(xlnx_gpio_in_t* gpio_in)
{
    if (assert_gpio_in(gpio_in) != UNINASOC_OK) {
        return UNINASOC_ERROR;
    };

    uintptr_t gpio_in_ier = (uintptr_t)(gpio_in->base_addr + GPIO_IN_IER);
    uintptr_t gpio_in_gier = (uintptr_t)(gpio_in->base_addr + GPIO_IN_GIER);

    if (gpio_in->interrupt == ENABLE_INT) {
        // Enable interrupt for the channel (1 in IP_IER)
        iowrite32(gpio_in_ier, 0x01);
        // Enable global interrupts (1 in GIER)
        iowrite32(gpio_in_gier, 0x80000000);
    }
    return UNINASOC_OK;
}

int xlnx_gpio_in_read(xlnx_gpio_in_t* gpio_in, uint16_t* data)
{
    if (assert_gpio_in(gpio_in) != UNINASOC_OK) {
        return UNINASOC_ERROR;
    };

    uintptr_t gpio_in_data = (uintptr_t)(gpio_in->base_addr + GPIO_IN_DATA);
    *data = ioread16(gpio_in_data);
    return UNINASOC_OK;
}

int xlnx_gpio_in_clear_int(xlnx_gpio_in_t* gpio_in)
{
    if (assert_gpio_in(gpio_in) != UNINASOC_OK) {
        return UNINASOC_ERROR;
    };

    uintptr_t gpio_in_isr = (uintptr_t)(gpio_in->base_addr + GPIO_IN_ISR);
    // Acknowledge GPIO interrupt has been handled.
    iowrite32(gpio_in_isr, 0x1);

    return UNINASOC_OK;
}

#endif
