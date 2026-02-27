// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  This file implements all the Output GPIO's related functions

#include "simplyv.h"

#ifdef GPIOOUT_IS_ENABLED

#include "io.h"
#include <stdint.h>



//Extend this function implementation in case you add more peripherals
static inline int assert_gpio_out(xlnx_gpio_out_t* gpio)
{
    if ((gpio->base_addr != _peripheral_GPIOOUT_start)) {
        return SIMPLYV_ERROR;
    }
    return SIMPLYV_OK;
}


int xlnx_gpio_out_init(xlnx_gpio_out_t* gpio)
{
    // Already configured in output as default
    if (assert_gpio_out(gpio) != SIMPLYV_OK){
        return SIMPLYV_ERROR;
    }
    return SIMPLYV_OK;
}

int xlnx_gpio_out_write(xlnx_gpio_out_t* gpio, pin_t val)
{
    if (assert_gpio_out(gpio) != SIMPLYV_OK)
        return SIMPLYV_ERROR;
    uintptr_t gpio_data = (uintptr_t)(gpio->base_addr + GPIO_DATA);
    iowrite16(gpio_data, val);
    return SIMPLYV_OK;
}

int xlnx_gpio_out_read(xlnx_gpio_out_t* gpio, uint16_t* data)
{
    if (assert_gpio_out(gpio) != SIMPLYV_OK)
        return SIMPLYV_ERROR;
    uintptr_t gpio_data = (uintptr_t)(gpio->base_addr + GPIO_DATA);
    *data = ioread16(gpio_data);
    return SIMPLYV_OK;
}

int xlnx_gpio_out_toggle(xlnx_gpio_out_t* gpio, pin_t pin)
{
    if (assert_gpio_out(gpio) != SIMPLYV_OK)
        return SIMPLYV_ERROR;

    if ((pin <= 0) || (pin > 0xFFFF))
        return SIMPLYV_ERROR;

    uint16_t data;
    xlnx_gpio_out_read(gpio, &data);
    data ^= pin;
    xlnx_gpio_out_write(gpio, data);
    return SIMPLYV_OK;
}

#endif
