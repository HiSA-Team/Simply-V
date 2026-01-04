// This file is auto-generated with halheader_template.py

#ifndef __UNINASOC_CONF_H__
#define __UNINASOC_CONF_H__

#include <stdint.h>

// Address of configured peripherals
#define _peripheral_BRAM_0_start  0x0000000000000000
#define _peripheral_BRAM_0_end    0x0000000000010000
#define _peripheral_DMmem_start  0x0000000000010000
#define _peripheral_DMmem_end    0x0000000000020000
#define _peripheral_CDMA_start  0x0000000000040000
#define _peripheral_CDMA_end    0x0000000000050000
#define _peripheral_PLIC_start  0x0000000004000000
#define _peripheral_PLIC_end    0x0000000008000000
#define _peripheral_UART_start  0x0000000000030000
#define _peripheral_UART_end    0x0000000000030010
#define _peripheral_GPIOOUT_start  0x0000000000030200
#define _peripheral_GPIOOUT_end    0x0000000000030400
#define _peripheral_GPIOIN_start  0x0000000000030400
#define _peripheral_GPIOIN_end    0x0000000000030600
#define _peripheral_TIM_0_start  0x0000000000030600
#define _peripheral_TIM_0_end    0x0000000000030620
#define _peripheral_TIM_1_start  0x0000000000030620
#define _peripheral_TIM_1_end    0x0000000000030640

// Enabled devices
#define TIM_IS_ENABLED 1
#define GPIOIN_IS_ENABLED 1
#define GPIOOUT_IS_ENABLED 1
#define UART_IS_ENABLED 1
#define CDMA_IS_ENABLED 1

#endif // __UNINASOC_CONF_H__
