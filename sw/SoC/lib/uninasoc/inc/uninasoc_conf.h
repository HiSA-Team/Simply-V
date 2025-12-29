// This file is auto-generated with halheader_template.py

#ifndef __UNINASOC_CONF_H__
#define __UNINASOC_CONF_H__

#include <stdint.h>

#define _peripheral_BRAM_0_start  0x0000000000000000
#define _peripheral_BRAM_0_end    0x0000000000010000
#define _peripheral_DMmem_start  0x0000000000010000
#define _peripheral_DMmem_end    0x0000000000020000
#define _peripheral_CDMA_start  0x0000000000030000
#define _peripheral_CDMA_end    0x0000000000040000
#define _peripheral_HlsControl_start  0x0000000000040000
#define _peripheral_HlsControl_end    0x0000000000050000
#define _peripheral_DDR4CH_1_start  0x0000000000050000
#define _peripheral_DDR4CH_1_end    0x0000000000060000
#define _peripheral_PLIC_start  0x0000000004000000
#define _peripheral_PLIC_end    0x0000000008000000
#define _peripheral_UART_start  0x0000000000020000
#define _peripheral_UART_end    0x0000000000020010
#define _peripheral_TIM_0_start  0x0000000000020020
#define _peripheral_TIM_0_end    0x0000000000020040
#define _peripheral_TIM_1_start  0x0000000000020040
#define _peripheral_TIM_1_end    0x0000000000020060
#define _peripheral_GPIOOUT_start  0x0000000000020060
#define _peripheral_GPIOOUT_end    0x0000000000020080
#define _peripheral_GPIOIN_start  0x0000000000020080
#define _peripheral_GPIOIN_end    0x00000000000200a0
#define _peripheral_DDR4CH_0_start  0x0000000000080000
#define _peripheral_DDR4CH_0_end    0x0000000000090000

#define CDMA_IS_ENABLED 1
#define UART_IS_ENABLED 1
#define GPIOOUT_IS_ENABLED 1
#define TIM_IS_ENABLED 1
#define GPIOIN_IS_ENABLED 1

#endif // __UNINASOC_CONF_H__
