// This file is auto-generated with halheader_template.py

#ifndef __SIMPLYV_CONF_H__
#define __SIMPLYV_CONF_H__

#include <stdint.h>

// Address of configured peripherals
#define _peripheral_BRAM_0_start  0x0000000000000000u
#define _peripheral_BRAM_0_end    0x0000000000010000u
#define _peripheral_DMmem_start  0x0000000000010000u
#define _peripheral_DMmem_end    0x0000000000020000u
#define _peripheral_CLINT_start  0x0000000000030000u
#define _peripheral_CLINT_end    0x0000000000040000u
#define _peripheral_CDMA_start  0x0000000000040000u
#define _peripheral_CDMA_end    0x0000000000050000u
#define _peripheral_PLIC_start  0x0000000004000000u
#define _peripheral_PLIC_end    0x0000000008000000u
#define _peripheral_UART_start  0x0000000000020000u
#define _peripheral_UART_end    0x0000000000020010u
#define _peripheral_GPIOOUT_start  0x0000000000020200u
#define _peripheral_GPIOOUT_end    0x0000000000020400u
#define _peripheral_GPIOIN_start  0x0000000000020400u
#define _peripheral_GPIOIN_end    0x0000000000020600u
#define _peripheral_TIM_0_start  0x0000000000020600u
#define _peripheral_TIM_0_end    0x0000000000020620u
#define _peripheral_TIM_1_start  0x0000000000020620u
#define _peripheral_TIM_1_end    0x0000000000020640u

// Enabled devices
#define CDMA_IS_ENABLED 1
#define CLINT_IS_ENABLED 1
#define GPIOIN_IS_ENABLED 1
#define GPIOOUT_IS_ENABLED 1
#define PLIC_IS_ENABLED 1
#define TIM_IS_ENABLED 1
#define UART_IS_ENABLED 1

// Clock Frequencies in Hz
#define MBUS_FREQ_MHz 20u
#define PBUS_FREQ_MHz 10u
#define BRAM_0_FREQ_MHz 20u
#define DMmem_FREQ_MHz 20u
#define CLINT_FREQ_MHz 20u
#define CDMA_FREQ_MHz 20u
#define PLIC_FREQ_MHz 20u
#define UART_FREQ_MHz 10u
#define GPIOOUT_FREQ_MHz 10u
#define GPIOIN_FREQ_MHz 10u
#define TIM_0_FREQ_MHz 10u
#define TIM_1_FREQ_MHz 10u

#endif // __SIMPLYV_CONF_H__
