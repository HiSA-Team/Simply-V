## Porting guide

This guide contains details on how to port FreeRTOS v11.2.0 on a RISC-V platform.

### System Tick Managemnet
For now the Simply-V SoC does not support a system timer. The SystemTick needs to be updated using a custom interrupt 
handler. On the timer ISR we need to implement the logic decribed in the picture from [here](https://rcc.freertos.org/Documentation/02-Kernel/05-RTOS-implementation-tutorial/02-Building-blocks/03-The-RTOS-tick).

This is done in the `vExternalTickIncrement()`:
```c
static void vExternalTickIncrement() {
  BaseType_t xSwitchRequired;

  // Clear interrupt flag
  xlnx_tim_clear_int(&timer);

  // Increment RTOS tick count
  xSwitchRequired = xTaskIncrementTick();

  // If a task was unblocked, yield to it
  if (xSwitchRequired != pdFALSE) {
    portYIELD_FROM_ISR(xSwitchRequired);
  }
}
```

### Trap vector configuration
The FreeRTOS integration is developed according to [this documentation page]([https://www.freertos.org/Using-FreeRTOS-on-RISC-V).

The `startup.S` installs the `freertos_risc_v_trap_handler` and configures the reset handler. 

The `_reset_handler` performs the following actions:
- reset registers
- install the trap handler (vectored mode)
- initializes the stack to `__stack_start`
- jumps into main

FreeRTOS vectored mode wants every entry of the vector table to point at the `freertos_risc_v_trap_handler`

> Note: If the RISC-V chip uses a vectored interrupt controller then install freertos_risc_v_trap_handler() 
as the handler for each vector.

```asm
.extern freertos_risc_v_trap_handler
.section .vector_table, "ax"
.align 4
.option norvc
/* In vectored mode all entries must go to -> freertos_risc_v_trap_handler */
/* https://www.freertos.org/Using-FreeRTOS-on-RISC-V#interrupt-system-stack-setup */
.rept 32
jal x0, freertos_risc_v_trap_handler
.endr
```

```asm
/* Set mtvec trap freertos_risc_v_trap_handler VECTORED mode. */
la a0, _vector_table_start  # Load vector table base address
li a1, 1                    # Set vectored mode bit
or a1, a1, a0
csrw mtvec, a1              # Commit on mtvec register
```

The timer peripheral is "TIM0" and it's managed through the PLIC. The "custom" interrupt 
handler can be specified by defining a `void freertos_risc_v_application_interrupt_handler(uint32_t mcause);` 
function (defined as `weak` by the FreeRTOS kernel) which will be called upon any external interrupt.
For example, if the SystemTimer has `interrupt_id = 2`, the trap handler would be like:
```c
void freertos_risc_v_application_interrupt_handler(uint32_t mcause) {
  (void) mcause;

  uint32_t interrupt_id = plic_claim();

  switch (interrupt_id) {
    case 0x2:
      vExternalTickIncrement();
      break;
    // other interrupts...
    default:
      break;
  }
  plic_complete(interrupt_id);
}
```

The trap stack needs to be configured. FreeRTOS supports reusing the initial stack as `xISRStack`.
This is achieved by defining the `__freertos_irq_stack_top` as equal to the `__stack_top` in the 
linkerscript as mentioned [here](https://www.freertos.org/Using-FreeRTOS-on-RISC-V#interrupt-system-stack-setup)

```
__bram_end        = ORIGIN(BRAM) + LENGTH(BRAM);
__stack_top       = __bram_end - 0x10;
__stack_size      = 0x1000; /* 4k */
__stack_bottom    = __stack_top - __stack_size;

/* https://www.freertos.org/Using-FreeRTOS-on-RISC-V#interrupt-system-stack-setup */
__freertos_irq_stack_top = __stack_top;
```

> [!Note]
> Make sure the `configISR_STACK_SIZE_WORDS` is not defined in the `FreeRTOSConfig.h`

### Timer configuration
The SoC does not have the MTIME so we need to start the timer defining the `void vPortSetupTimerInterrupt(void)`.
The function enables the PLIC, configures, starts and enables timer interrupt. Since we do not have 
the MTIME, the timer interrupt will be just enabled as a normal external interrupt (MEI bit in MIE):

```c
void vPortSetupTimerInterrupt(void) {
  // configure and init PLIC
  plic_init();
  // other functions omitted...

  // create a Timer Instance
  xlnx_tim_init(&timer);
  // validate and enable timer interrupts... (not shown here)

  // start the timer
  ret = xlnx_tim_start(&timer);
  if (ret != UNINASOC_OK) {
    printf("Cannot start timer\r\n");
    return;
  }

  // Enable local interrupts lines
  // MEI (External Interrupt)
  __asm volatile ( "csrs mie, %0" ::"r" ( 0x800 ) );
}
```
