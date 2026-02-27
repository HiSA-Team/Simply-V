// Author: Stefano Mercogliano <stefano.mercogliano@unina.it>
// Author: Valerio Di Domenico <valer.didomenico@studenti.unina.it>
// Author: Salvatore Santoro <sal.santoro@studenti.unina.it>
// Author: Vincenzo Maisto <vincenzo.maisto2@unina.it>
// Description:
//      This code demonstrates the usage interrupts with CLINT and PLIC.
//      This example assumes:
//          - two interrupt lines connected to the PLIC: GPIO_IN and TIM0
//          - PLIC interrupt line connected to the CPU external interrupt port
//          - CLINT timer interrupt line connected to the CPU timer interrupt port
//      Behaviour:
//          - Until MAX_INTERRUPTS interrupts are served:
//             - GPIO_IN interrupts trigger a toggle on led 0 (overriding default _ext_handler)
//             - TIM0 timer interrupts trigger a toggle on led 1 (overriding default _ext_handler)
//             - CLINT timer interrupts trigger a toggle on led 2 (overriding default _timer_handler)
//          - Interrupt count is printed before exit
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

// Timer0 count in microseconds
#define TIM0_COUNT_US (500000u)
// Reset counter value for one interrupt each 0.5 seconds
#define TIM0_COUNT_TICKS (TIM0_COUNT_US * TIM_0_FREQ_MHz)

xlnx_tim_t timer0 = {
    .base_addr       = TIM0_BASEADDR,
    .counter         = TIM0_COUNT_TICKS,
    .reload_mode     = TIM_RELOAD_AUTO,
    .count_direction = TIM_COUNT_DOWN
};

// Global interrupts count
int ext_interrupt_count;
int timer_interrupt_count;

// Maximum number of interrupts before exiting
#define MAX_INTERRUPTS 10
// Maximum number of external (PLIC) interrupts before exiting
#define MAX_PLIC_INTERRUPTS 10

void _timer_handler(void)
{
    // Toggle
    #ifdef GPIO_OUT_IS_ENABLED
    xlnx_gpio_out_toggle(&gpio_out, PIN_2);
    #endif // GPIO_OUT_IS_ENABLED

    // Count up
    timer_interrupt_count++;
    printf("[_timer_handler] Handiling timer interrupt, count %d\r\n", timer_interrupt_count);

    // Set flag
    _timer_handler_flag = 1;

    // Disable CLINT
    clint_disable();
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
    //

    // Increment counter
    // NOTE: this is not thread-safe
    ext_interrupt_count++;

    // Get interrupt ID
    uint32_t interrupt_id = plic_claim();
    switch (interrupt_id) {

    case PLIC_GPIOIN_INTERRUPT:
        printf("[_ext_handler] Handiling GPIO_IN interrupt, count %d\r\n", interrupt_count);
        #ifdef GPIOOUT_IS_ENABLED
        xlnx_gpio_out_toggle(&gpio_out, PIN_0);
        #endif // GPIOOUT_IS_ENABLED
        #ifdef GPIOIN_IS_ENABLED
        xlnx_gpio_in_clear_int(&gpio_in);
        #endif // GPIOIN_IS_ENABLED
        break;
    case PLIC_TIM_0_INTERRUPT:
        // Timer interrupt
        printf("[_ext_handler] Handiling TIM0 interrupt, count %d\r\n", interrupt_count);
        #ifdef GPIOOUT_IS_ENABLED
        xlnx_gpio_out_toggle(&gpio_out, PIN_1);
        #endif // GPIOOUT_IS_ENABLED
        xlnx_tim_clear_int(&timer0);
        break;
    default:
        // Skip this interrupt
        break;
    }

    // To notify the handler completion, a write-back on the claim/complete register is required.
    plic_complete(interrupt_id);

    // Check interrupt count
    if ( ext_interrupt_count >= MAX_PLIC_INTERRUPTS ) {
        // Clean up
        printf("[_ext_handler] All expected interrupts handled, stopping timer0\r\n");
        if (xlnx_tim_stop( &timer0 ) != SIMPLYV_OK)
            printf("[_ext_handler][ERROR] TIM0 stop\r\n");
    }

}


// Main function
int main()
{
    int retval;

    // Initialize HAL
    simplyv_init();

    // Reset global counters
    ext_interrupt_count = 0;
    timer_interrupt_count = 0;

    printf("Interrupts Example\r\n");
    printf("[main] TIM0 interrupt period = %u us\r\n", TIM0_COUNT_US);

    // Init PLIC
    retval = plic_init();
    if ( retval != SIMPLYV_OK ) {
        printf("[main][ERROR] PLIC init\r\n");
        return retval;
    }
    // Configure the PLIC for GPIOIN and TIM0, same priority
    uint32_t priority = 1;
    plic_configure_set_one(priority, PLIC_GPIOIN_INTERRUPT);
    plic_configure_set_one(priority, PLIC_TIM_0_INTERRUPT);
    plic_enable_all();

    #ifdef GPIOIN_IS_ENABLED
    retval = retval = xlnx_gpio_in_init(&gpio_in);
    if ( retval != SIMPLYV_OK ) {
        printf("[main][ERROR] GPIOIN interrupt init\r\n");
        return retval;
    }
    #endif // GPIOIN_IS_ENABLED

    #ifdef GPIOOUT_IS_ENABLED
    retval = xlnx_gpio_out_init(&gpio_out);
    if ( retval != SIMPLYV_OK ) {
        printf("[main][ERROR] GPIOOUT\r\n");
        return retval;
    }
    #endif // GPIOOUT_IS_ENABLED

    // Configure timer0
    retval = xlnx_tim_init( &timer0 );
    if ( retval != SIMPLYV_OK ) {
        printf("[main][ERROR] TIMER INIT\r\n");
        return retval;
    }

    retval = xlnx_tim_configure( &timer0 );
    if ( retval != SIMPLYV_OK ) {
        printf("[main][ERROR] TIMER CONFIG\r\n");
        return retval;
    }

    // Enable interrupts
    retval = xlnx_tim_enable_int( &timer0 );
    if ( retval != SIMPLYV_OK ) {
        printf("[main][ERROR] TIMER interrupt enable\r\n");
        return retval;
    }

    // Start timer0
    retval = xlnx_tim_start( &timer0 );
    if ( retval != SIMPLYV_OK ) {
        printf("[main][ERROR] TIMER start\r\n");
        return retval;
    }

    // Hot-loop, waiting for interrupts to occur
    printf("[main] Wait for interrupts\r\n");
    // NOTE: this is not a safe way to synchronize with the handlers,
    //       rather a simple way to terminate the program
    // TODO: use atomics to sync with handlers
    while ( (timer_interrupt_count + ext_interrupt_count) < MAX_INTERRUPTS ) {
        // Sleep with CLINT
        uint32_t sleep_us = 3000000u;
        printf("[main] Interrupts are not done, sleeping for %u us...\r\n", sleep_us);
        retval = clint_sleep_us( sleep_us );
        if ( retval != SIMPLYV_OK ) {
            printf("[main][ERROR] CLINT sleep\r\n");
            return retval;
        }
    }

    // Info
    printf("[main] Returning from main, interrupt count:\r\n");
    printf("[main] \text_interrupt   = %d\n\r", ext_interrupt_count);
    printf("[main] \ttimer_interrupt = %d\n\r", timer_interrupt_count);

    return SIMPLYV_OK;
}
