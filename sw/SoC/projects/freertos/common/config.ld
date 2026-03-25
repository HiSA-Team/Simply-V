/* let's assume this memory block is defined in simplyv.ld */
__bram_end     = ORIGIN(BRAM) + LENGTH(BRAM);
__stack_size   = 0x1000; /* 4k */
__stack_bottom = _stack_start - __stack_size;

/* https://www.freertos.org/Using-FreeRTOS-on-RISC-V#interrupt-system-stack-setup */
__freertos_irq_stack_top = _stack_start;
