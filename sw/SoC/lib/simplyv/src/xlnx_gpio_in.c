// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  This file implements all the Input GPIO's related functions

#include "simplyv.h"

#ifdef GPIOIN_IS_ENABLED

#include "io.h"
#include <stdint.h>

// Extend this function implementation in case you add more peripherals
static inline int assert_gpio_in(xlnx_gpio_in_t* gpio)
{
    if ((gpio->base_addr != _peripheral_GPIOIN_start)) {
        return SIMPLYV_ERROR;
    }
    return SIMPLYV_OK;
}

int xlnx_gpio_in_init(xlnx_gpio_in_t* gpio_in)
{
    if (assert_gpio_in(gpio_in) != SIMPLYV_OK) {
        return SIMPLYV_ERROR;
    };

    uintptr_t gpio_in_ier = (uintptr_t)(gpio_in->base_addr + GPIO_IN_IER);
    uintptr_t gpio_in_gier = (uintptr_t)(gpio_in->base_addr + GPIO_IN_GIER);

    if (gpio_in->interrupt == ENABLE_INT) {
        // Enable interrupt for the channel (1 in IP_IER)
        iowrite32(gpio_in_ier, 0x01);
        // Enable global interrupts (1 in GIER)
        iowrite32(gpio_in_gier, 0x80000000);
    }
    return SIMPLYV_OK;
}

int xlnx_gpio_in_read(xlnx_gpio_in_t* gpio_in, uint16_t* data)
{
    if (assert_gpio_in(gpio_in) != SIMPLYV_OK) {
        return SIMPLYV_ERROR;
    };

    uintptr_t gpio_in_data = (uintptr_t)(gpio_in->base_addr + GPIO_IN_DATA);
    *data = ioread16(gpio_in_data);
    return SIMPLYV_OK;
}

int xlnx_gpio_in_clear_int(xlnx_gpio_in_t* gpio_in)
{
    if (assert_gpio_in(gpio_in) != SIMPLYV_OK) {
        return SIMPLYV_ERROR;
    };

    uintptr_t gpio_in_isr = (uintptr_t)(gpio_in->base_addr + GPIO_IN_ISR);
    // Acknowledge GPIO interrupt has been handled.
    iowrite32(gpio_in_isr, 0x1);

    return SIMPLYV_OK;
}

#endif
