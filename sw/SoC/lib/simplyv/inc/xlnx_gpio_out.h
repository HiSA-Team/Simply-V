// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//  This file defines the API to adoperate the Xilinx Output GPIO
// Reference: https://docs.amd.com/v/u/en-US/pg144-axi-gpio

#ifndef _XLNX_GPIO_OUT_H
#define _XLNX_GPIO_OUT_H


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

// The GPIO OUT peripheral has 16 output pins
// every bit in the "DATA" register controls the output of each pins
// here are defined the values to place in the data register to activate each pin
// PIN_0 = 2^0 = 1 (first bit)
// PIN_1 = 2^1 = 2 (second bit)
// and so on...
typedef enum {
    PIN_0 = (1 << 0),
    PIN_1 = (1 << 1),
    PIN_2 = (1 << 2),
    PIN_3 = (1 << 3),
    PIN_4 = (1 << 4),
    PIN_5 = (1 << 5),
    PIN_6 = (1 << 6),
    PIN_7 = (1 << 7),
    PIN_8 = (1 << 8),
    PIN_9 = (1 << 9),
    PIN_10 = (1 << 10),
    PIN_11 = (1 << 11),
    PIN_12 = (1 << 12),
    PIN_13 = (1 << 13),
    PIN_14 = (1 << 14),
    PIN_15 = (1 << 15),
    PIN_ALL = 0xFFFF // All pins bits
} pin_t;

// Need to be initialized with _peripheral_GPIOOUT_start
typedef struct {
    uintptr_t base_addr;
} xlnx_gpio_out_t;


//All the Functions return SIMPLYV_ERROR in case of error and SIMPLYV_OK otherwise

// Initializes the gpio out peripheral
int xlnx_gpio_out_init(xlnx_gpio_out_t* gpio);

// Raise the selected pin (to raise multiple pins just use bitwise OR es. PIN_0 | PIN_1)
int xlnx_gpio_out_write(xlnx_gpio_out_t* gpio, pin_t val);

// Read the content of the DATA register
int xlnx_gpio_out_read(xlnx_gpio_out_t* gpio, uint16_t* data);

// Toggle the selected pin(s) switching 0 and 1 back and forth
int xlnx_gpio_out_toggle(xlnx_gpio_out_t* gpio, pin_t pin);

#endif // _XLNX_GPIO_OUT_H
