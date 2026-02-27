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
#define _peripheral_HLSCONTROL_start  0x0000000000050000u
#define _peripheral_HLSCONTROL_end    0x0000000000060000u
#define _peripheral_DDR4CH_1_start  0x0000000000060000u
#define _peripheral_DDR4CH_1_end    0x0000000000070000u
#define _peripheral_PLIC_start  0x0000000004000000u
#define _peripheral_PLIC_end    0x0000000008000000u
#define _peripheral_UART_start  0x0000000000020000u
#define _peripheral_UART_end    0x0000000000020010u
#define _peripheral_TIM_0_start  0x0000000000020600u
#define _peripheral_TIM_0_end    0x0000000000020620u
#define _peripheral_TIM_1_start  0x0000000000020620u
#define _peripheral_TIM_1_end    0x0000000000020640u
#define _peripheral_DDR4CH_0_start  0x0000000000080000u
#define _peripheral_DDR4CH_0_end    0x0000000000090000u

// Enabled devices
#define CDMA_IS_ENABLED 1
#define CLINT_IS_ENABLED 1
#define PLIC_IS_ENABLED 1
#define TIM_IS_ENABLED 1
#define UART_IS_ENABLED 1

// Clock Frequencies in Hz
#define MBUS_FREQ_MHz 100u
#define PBUS_FREQ_MHz 250u
#define HBUS_FREQ_MHz 300u
#define BRAM_0_FREQ_MHz 100u
#define DMmem_FREQ_MHz 100u
#define CLINT_FREQ_MHz 100u
#define CDMA_FREQ_MHz 100u
#define HLSCONTROL_FREQ_MHz 300u
#define DDR4CH_1_FREQ_MHz 300u
#define PLIC_FREQ_MHz 100u
#define UART_FREQ_MHz 250u
#define TIM_0_FREQ_MHz 250u
#define TIM_1_FREQ_MHz 250u
#define DDR4CH_0_FREQ_MHz 300u

#endif // __SIMPLYV_CONF_H__
