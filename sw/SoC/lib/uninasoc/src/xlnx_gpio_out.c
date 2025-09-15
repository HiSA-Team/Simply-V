// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  This file implements all the Output GPIO's related functions

#include "uninasoc.h"

// #ifdef IS_EMBEDDED // TODO47: placeholder to HAL

#ifdef GPIO_OUT_IS_ENABLED
#include "io.h"
#include <stdint.h>


// Registers
#define GPIO_DATA 0x0000 // Data Register
#define GPIO_TRI 0x0004 // Direction Register
#define GPIO2_DATA 0x0008 // Data register second channel
#define GPIO2_TRI 0x000C // Data register second channel
#define GIER 0x011C // Global Interrupt Enable Register
#define IP_ISR 0x0120 // Interrupt Status Register
#define IP_IER 0x0128 // Interrupt Enable Register


//Extend this function implementation in case you add more peripherals
static inline int assert_gpio_out(xlnx_gpio_out_t* gpio)
{
    if ((gpio->base_addr != GPIO_OUT_BASEADDR)) {
        return UNINASOC_ERROR;
    }
    return UNINASOC_OK;
}


int xlnx_gpio_out_init(xlnx_gpio_out_t* gpio)
{
    // Already configured in output as default
    if (assert_gpio_out(gpio) != UNINASOC_OK){
        return UNINASOC_ERROR;
    }
    return UNINASOC_OK;
}

int xlnx_gpio_out_write(xlnx_gpio_out_t* gpio, pin_t val)
{
    if (assert_gpio_out(gpio) != UNINASOC_OK)
        return UNINASOC_ERROR;
    uintptr_t gpio_data = (uintptr_t)(gpio->base_addr + GPIO_DATA);
    iowrite16(gpio_data, val);
    return UNINASOC_OK;
}

int xlnx_gpio_out_read(xlnx_gpio_out_t* gpio, uint16_t* data)
{
    if (assert_gpio_out(gpio) != UNINASOC_OK)
        return UNINASOC_ERROR;
    uintptr_t gpio_data = (uintptr_t)(gpio->base_addr + GPIO_DATA);
    *data = ioread16(gpio_data);
    return UNINASOC_OK;
}

int xlnx_gpio_out_toggle(xlnx_gpio_out_t* gpio, pin_t pin)
{
    if (assert_gpio_out(gpio) != UNINASOC_OK)
        return UNINASOC_ERROR;

    if ((pin <= 0) || (pin > 0xFFFF))
        return UNINASOC_ERROR;

    uint16_t data;
    xlnx_gpio_out_read(gpio, &data);
    data ^= pin;
    xlnx_gpio_out_write(gpio, data);
    return UNINASOC_OK;
}

#endif
