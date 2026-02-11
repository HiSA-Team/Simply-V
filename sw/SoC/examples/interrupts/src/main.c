// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Description:
//      This code demonstrates the usage of PLIC and interrupts.
//      Physically, three interrupt lines are connected (in addition to line 0, which is reserved).
//      Logically, two interrupt sources are utilized: a timer0 and gpio_in (embedded only).
//          - GPIO_IN interrupts trigger a toggle on led 0.
//          - TIM0 timer0 interrupts trigger a toggle on led 1.
//
//      Note 1: The PLIC is connected to the core via the EXT line. Both the timer0 and gpio_in are expected
//      to be connected to the PLIC. The timer0 must NOT be connected directly to the core's TIM line in this example.
//
//      Note 2: The IS_EMBEDDED macro is automatically defined depending on SoC profile
//

#include "simplyv.h"
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

// Reset counter value for one interrupt each second (assuming a 10MHz clock)
#define COUNT_VALUE 10000000

xlnx_tim_t timer0 = {
    .base_addr       = TIM0_BASEADDR,
    .counter         = COUNT_VALUE,
    .reload_mode     = TIM_RELOAD_AUTO,
    .count_direction = TIM_COUNT_DOWN
};

// IMPORTANT:
// when defining custom handlers always use the "__irq_handler__" symbol
// this symbol is crucial, omitting it would make the compiler treat them like normal functions
// creating wrong epilogue and prologue

void _sw_handler() __irq_handler__;
void _timer_handler() __irq_handler__;
void _ext_handler() __irq_handler__;

// Global interrupts count
int ext_interrupt_count;
int timer_interrupt_count;

void _sw_handler(void)
{
    // Unused for this example
}

void _timer_handler(void)
{
    // Toggle
    #ifdef GPIO_OUT_IS_ENABLED
    xlnx_gpio_out_toggle(&gpio_out, PIN_2);
    #endif // GPIO_OUT_IS_ENABLED

    // Count up
    timer_interrupt_count++;
    printf("[_timer_handler] Handiling timer interrupt, count %d\r\n", timer_interrupt_count);

}

// Maximum number of interrupts before exiting
#define MAX_INTERRUPTS 10

void _ext_handler(void)
{

    // Interrupts are automatically disabled by the microarchitecture.
    // Nested interrupts can be enabled manually by setting the IE bit in the mstatus register,
    // but this requires careful handling of registers.
    // Interrupts are automatically re-enabled by the microarchitecture when the MRET instruction is executed.

    // In this example, the core is connected to PLIC target 1 line.
    // Therefore, we need to access the PLIC claim/complete register 1 (base_addr + 0x200004).
    // The interrupt source ID is obtained from the claim register.

    // Increment counter
    // NOTE: this is not thread-safe
    ext_interrupt_count++;

    // Get interrupt ID
    uint32_t interrupt_id = plic_claim();
    switch (interrupt_id) {
    case PLIC_GPIOIN_INTERRUPT:
        printf("[_ext_handler] Handiling GPIO_IN interrupt, count %d\r\n", ext_interrupt_count);
        #ifdef GPIO_OUT_IS_ENABLED
        xlnx_gpio_out_toggle(&gpio_out, PIN_0);
        #endif // GPIO_OUT_IS_ENABLED
        #ifdef GPIO_IN_IS_ENABLED
        xlnx_gpio_in_clear_int(&gpio_in);
        #endif // GPIO_IN_IS_ENABLED
        break;
    case PLIC_TIM0_INTERRUPT:
        // Timer interrupt
        printf("[_ext_handler] Handiling TIM0 interrupt, count %d\r\n", ext_interrupt_count);
        #ifdef GPIO_OUT_IS_ENABLED
        xlnx_gpio_out_toggle(&gpio_out, PIN_1);
        #endif // GPIO_OUT_IS_ENABLED
        xlnx_tim_clear_int(&timer0);
        break;
    default:
        // Skip this interrupt
        break;
    }

    // To notify the handler completion, a write-back on the claim/complete register is required.
    plic_complete(interrupt_id);

    // Check interrupt count
    if ( ext_interrupt_count >= MAX_INTERRUPTS ) {
        // Clean up
        printf("[_ext_handler] All expected interrupts handled, stopping timer0\r\n");
        if (xlnx_tim_stop(&timer0) != SIMPLYV_OK)
            printf("ERROR TIMER stop\r\n");
    }

}


// Main function
int main()
{
    // Initialize HAL
    simplyv_init();

    // clint_clean();

    // Reset global counters
    ext_interrupt_count = 0;
    timer_interrupt_count = 0;

    printf("Interrupts Example\r\n");

    // Configure the PLIC for GPIOIN and TIM0, same priority
    uint32_t priority = 1;
    plic_init();
    plic_configure_set_one(priority, PLIC_GPIOIN_INTERRUPT);
    plic_configure_set_one(priority, PLIC_TIM0_INTERRUPT);
    plic_enable_all();

    #ifdef GPIO_IN_IS_ENABLED
    if (xlnx_gpio_in_init(&gpio_in) != SIMPLYV_OK)
        printf("ERROR GPIOIN interrupt init\r\n");
    #endif // GPIO_IN_IS_ENABLED

    #ifdef GPIO_OUT_IS_ENABLED
    if (xlnx_gpio_out_init(&gpio_out) != SIMPLYV_OK)
        printf("ERROR GPIOOUT\r\n");
    #endif // GPIO_OUT_IS_ENABLED

    // Configure timer0
    if (xlnx_tim_init(&timer0) != SIMPLYV_OK)
        printf("ERROR TIMER INIT\r\n");

    if (xlnx_tim_configure(&timer0) != SIMPLYV_OK)
        printf("ERROR TIMER CONFIG\r\n");

    // Enable interrupts
    if (xlnx_tim_enable_int(&timer0) != SIMPLYV_OK)
        printf("ERROR TIMER interrupt enable\r\n");

    // Start timer0
    if (xlnx_tim_start(&timer0) != SIMPLYV_OK)
        printf("ERROR TIMER start\r\n");

    // Hot-loop, waiting for interrupts to occur
    // NOTE: this is not a safe way to synchronize with the _ext_handler,
    //       rather a simple way to terminate the program
    while ( ext_interrupt_count < MAX_INTERRUPTS );

    // Info
    printf("Returning from main, interrupt count:\r\n");
    printf("\text_interrupt: %d\n\r", ext_interrupt_count);
    printf("\ttimer_interrupt: %d\n\r", timer_interrupt_count);

    return SIMPLYV_OK;
}
