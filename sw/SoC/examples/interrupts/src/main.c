// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//      This code demonstrates the usage of PLIC and interrupts.
//      Physically, three interrupt lines are connected (in addition to line 0, which is reserved).
//      Logically, two interrupt sources are utilized: a timer and gpio_in (embedded only).
//          - GPIO_IN interrupts trigger a toggle on led 0.
//          - TIM0 timer interrupts trigger a toggle on led 1.
//
//      Note 1: The PLIC is connected to the core via the EXT line. Both the timer and gpio_in are expected
//      to be connected to the PLIC. The timer must NOT be connected directly to the core's TIM line in this example.
//
//      Note 2: The IS_EMBEDDED macro is automatically defined depending on SoC profile
//

#include "uninasoc.h"
#include <stdint.h>

#define SOURCES_NUM 3 // regardless of embedded/hpc

#ifdef IS_EMBEDDED
xlnx_gpio_in_t gpio_in = {
    .base_addr = GPIO_IN_BASEADDR,
    .interrupt = ENABLE_INT
};

xlnx_gpio_out_t gpio_out = {
    .base_addr = GPIO_OUT_BASEADDR
};
#endif // IS_EMBEDDED

xlnx_tim_t timer = {
    .base_addr = TIM0_BASEADDR,
    .counter = 20000000,
    .reload_mode = TIM_RELOAD_AUTO,
    .count_direction = TIM_COUNT_DOWN
};

// IMPORTANT:
// when defining custom handlers always use the "__irq_handler__" symbol
// this symbol is crucial, omitting it would make the compiler treat them like normal functions
// creating wrong epilogue and prologue

void _sw_handler() __irq_handler__;
void _timer_handler() __irq_handler__;
void _ext_handler() __irq_handler__;

void _sw_handler(void)
{
    // Unused for this example
}

void _timer_handler(void)
{
    // Unused for this example
}

void _ext_handler(void)
{
    // Interrupts are automatically disabled by the microarchitecture.
    // Nested interrupts can be enabled manually by setting the IE bit in the mstatus register,
    // but this requires careful handling of registers.
    // Interrupts are automatically re-enabled by the microarchitecture when the MRET instruction is executed.

    // In this example, the core is connected to PLIC target 1 line.
    // Therefore, we need to access the PLIC claim/complete register 1 (base_addr + 0x200004).
    // The interrupt source ID is obtained from the claim register.

    uint32_t interrupt_id = plic_claim();
    switch (interrupt_id) {
    case 0x0: // unused
        break;
    case 0x1:
        printf("Handiling GPIO_IN interrupt!\r\n");
        #ifdef GPIO_OUT_IS_ENABLED
        xlnx_gpio_out_toggle(&gpio_out, PIN_0);
        #endif // GPIO_OUT_IS_ENABLED
        #ifdef GPIO_IN_IS_ENABLED
        xlnx_gpio_in_clear_int(&gpio_in);
        #endif // GPIO_IN_IS_ENABLED
        break;
    case 0x2:
        // Timer interrupt
        printf("Handiling TIM0 interrupt!\r\n");
        #ifdef GPIO_OUT_IS_ENABLED
        xlnx_gpio_out_toggle(&gpio_out, PIN_1);
        #endif // GPIO_OUT_IS_ENABLED
        xlnx_tim_clear_int(&timer);
        break;
    default:
        break;
    }

    // To notify the handler completion, a write-back on the claim/complete register is required.
    plic_complete(interrupt_id);
}


// Main function
int main()
{
    // Initialize HAL
    uninasoc_init();

    printf("Interrupts Example\r\n");

    // Configure the PLIC
    uint32_t priorities[SOURCES_NUM] = { 1, 1, 1 };
    plic_init();
    plic_configure_set_array(priorities, SOURCES_NUM);
    plic_enable_all();

    #ifdef GPIO_IN_IS_ENABLED
    if (xlnx_gpio_in_init(&gpio_in) != UNINASOC_OK)
        printf("ERROR GPIOIN\r\n");
    #endif // GPIO_IN_IS_ENABLED

    #ifdef GPIO_OUT_IS_ENABLED
    if (xlnx_gpio_out_init(&gpio_out) != UNINASOC_OK)
        printf("ERROR GPIOOUT\r\n");
    #endif // GPIO_OUT_IS_ENABLED

    // Configure the timer for one interrupt each second (assuming a 20MHz clock)
    xlnx_tim_init(&timer);

    if (xlnx_tim_configure(&timer) != UNINASOC_OK)
        printf("ERROR TIMER\r\n");

    if (xlnx_tim_enable_int(&timer) != UNINASOC_OK)
        printf("ERROR TIMER\r\n");

    if (xlnx_tim_start(&timer) != UNINASOC_OK)
        printf("ERROR TIMER\r\n");

    // Hot-loop, waiting for interrupts to occur
    while (1);

    return 0;
}
