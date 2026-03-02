/*
 * SPDX-License-Identifier: BSD-2-Clause
 *
 * Copyright (c) 2019 Western Digital Corporation or its affiliates.
 */

/*
 * Main porting file for SIMPLYV platform. The goal is to provide the following structs:
 *
 *
 * const struct sbi_platform_operations platform_ops = {
 *   .cold_boot_allowed  = simplyv_generic_cold_boot_allowed,
 *   .early_init         = simplyv_platform_early_init,
 *   .irqchip_init       = simplyv_irqchip_init,
 *   .timer_init         = simplyv_timer_init,
 * };
 *
 *  const struct sbi_platform platform = {
 *  .opensbi_version    = OPENSBI_VERSION,
 *  .platform_version   = SBI_PLATFORM_VERSION(0x0, 0x00),
 *  .name               = "simply-v",
 *  .features           = SBI_PLATFORM_DEFAULT_FEATURES,
 *  .hart_count         = SIMPLYV_HART_COUNT,
 *  .hart_stack_size    = SBI_PLATFORM_DEFAULT_HART_STACK_SIZE,
 *  .heap_size          = SBI_PLATFORM_DEFAULT_HEAP_SIZE(1),
 *  .platform_ops_addr  = (unsigned long)&platform_ops
 * };
 *
 * Provided function hooks will be executed in different stage of the bootloading. For example,
 * `early_init` initializes the debug console, while cold_boot_allowed returns 0 if the hart id
 * can perform cald boot.
 *
 * The code uses OpenSBI library to import all `sbi_*` function. For example, we need to register
 * the UART as console device (the one used by OpenSBI for the DBCN).
 *
 * Original at .opensbi/platform/template/platform.c
 * Author: Giuseppe Capasso <giuseppe.capasso17@studenti.unina.it>
 */

#include <sbi/riscv_asm.h>
#include <sbi/riscv_encoding.h>
#include <sbi/sbi_const.h>
#include <sbi/sbi_console.h>
#include <sbi/sbi_platform.h>


/* Platform specific configuration */
#define SIMPLYV_HART_COUNT 1
#include "simplyv_conf.h"

/*
 * Using Kconfig we can specify to use the Xilinx Serial driver provided by OpenSBI by selecting
 * SIMPLYV_USE_XILINX_SERIAL. The implementation fallbacks to the tinyIO implementation.
 */
#ifndef CONFIG_SIMPLYV_USE_XILINX_SERIAL

#include "tinyIO.h"
#include "uart.h"
/*
 * Adapter for tinyio putc
 */
static void console_putc_adapter(char ch)
{

    uart_send_char((uint8_t)ch);

}

/*
 * Adapter for tinyio getc
 */
static int console_getc_adapter(void)
{

    return (int) uart_get_char();

}

static const struct sbi_console_device simplyv_uart_console = {
    .name = "simplv-uart",
    .console_putc = console_putc_adapter,
    .console_getc = console_getc_adapter,
};

/*
 * Platform early initialization.
 */
static int simplyv_platform_early_init(bool cold_boot)
{
    if (!cold_boot)
        return 0;

    /* Init TinyIO */
    tinyIO_init(_peripheral_UART_start);
    sbi_console_set_device(&simplyv_uart_console);
    return 0;
}

#else

#include <sbi_utils/serial/xlnx_uartlite.h>

/*
 * Platform early initialization.
 */
static int simplyv_platform_early_init(bool cold_boot)
{
    if (!cold_boot)
        return 0;

    return xlnx_uartlite_init(_peripheral_UART_start);
}

#endif //! SIMPLYV_USE_UARTLITE

bool simplyv_generic_cold_boot_allowed(u32 hartid)
{

    /* We must enable at least one hart for cold boot. In this case, hart 0 will be the only hart in the platform */
    return hartid == 0;

}

/*
 * Initialize and configure PLIC and interrutps
 *
 * Note:  No interrupts in this PR
 * TODO: understand minimal interrupts to be enabled for startup
 */
static int simplyv_irqchip_init(void)
{

    return 0;

}

/*
 * Initialize timer
 */
static int simplyv_timer_init(void)
{

    return 0;

}

/*
 * Platform descriptor. Refer to opensbi/include/sbi/sbi_platform.h for full definition of platform
 * operation structs.
 */
const struct sbi_platform_operations platform_ops = {
    .cold_boot_allowed  = simplyv_generic_cold_boot_allowed,
    .early_init         = simplyv_platform_early_init,
    .irqchip_init       = simplyv_irqchip_init,
    .timer_init         = simplyv_timer_init,
};

/*
 * This struct contains all definition for the platform including a reference to platform_operations,
 * number of HARTs, stack size per hart and HEAP size.
 */
const struct sbi_platform platform = {
    .opensbi_version    = OPENSBI_VERSION,
    .platform_version   = SBI_PLATFORM_VERSION(0x0, 0x00),
    .name               = "simply-v",
    .features           = SBI_PLATFORM_DEFAULT_FEATURES,
    .hart_count         = SIMPLYV_HART_COUNT,
    .hart_stack_size    = SBI_PLATFORM_DEFAULT_HART_STACK_SIZE,
    .heap_size          = SBI_PLATFORM_DEFAULT_HEAP_SIZE(1),
    .platform_ops_addr  = (unsigned long)&platform_ops
};
