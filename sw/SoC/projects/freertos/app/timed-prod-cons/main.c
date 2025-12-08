/*
 *  This example shows a Producer-Consumer with a timer. The Producer is a periodic task which uses 
 *  the `vTaskDelayUntil` promitives to suspend until the new period starts. The producer sends a 
 *  counter which is increment by the passed as input. The Consumer receives the value and simulates some 
 *  work with `vTaskDelay` primitive.
 *
 *  The System Timer in FreeRTOS using the Simply-V timer peripheral. The Simply-V timer peripheral is behind a PLIC. To enable and configure  the Timer 
 *  we need to implement the `vPortSetupTimerInterrupt` (defined as weak and callend by the OS during initialization).
 *  Finally, we need to provide `void freertos_risc_v_application_interrupt_handler` (defined as weak) and handle 
 *  the timer interrupt. The handler routine should call the `vExternalTickIncrement` function to 
 *  increment the System Tick (it will also call the context switch).
 *
 * Author: Giusppe Capasso <giuseppe.capasso17@studenti.unina.it>
 */

#include "FreeRTOS.h"
#include "queue.h"
#include "task.h"

#include "uninasoc.h"

/*  =============================== Variables ================================ */
static xlnx_tim_t timer = {.base_addr = TIM0_BASEADDR,
                           .counter = 200000,
                           .reload_mode = TIM_RELOAD_AUTO,
                           .count_direction = TIM_COUNT_DOWN};
static QueueHandle_t xQueue = NULL;

#define PRODUCER_TASK_PRIORITY (tskIDLE_PRIORITY + 1)
#define CONSUMER_TASK_PRIORITY (PRODUCER_TASK_PRIORITY + 1)

#define PRODUCER_PARAMETER (1)
#define QUEUE_LENGTH (1)

/*  =============================== Functions ================================  */
static void  queueProducerTaskTimer(void *pvParameters) {

  configASSERT(((uint32_t)pvParameters) == PRODUCER_PARAMETER);

  TickType_t xLastWakeTime;
  uint32_t amt = (uint32_t)pvParameters;
  uint32_t counter = 0;
  const TickType_t xFrequency = 100;

  // Initialise the xLastWakeTime variable with the current time.
  xLastWakeTime = xTaskGetTickCount();

  while (1) {
    counter += amt;
    printf("[Producer Task]: sending: %d \n\r", counter);

    xQueueSend(xQueue, &counter, 0U);

    // Wait for the next cycle.
    vTaskDelayUntil(&xLastWakeTime, xFrequency);
  }
}

static void queueConsumerTaskTimer(void *pvParameters) {
  (void)pvParameters;

  uint32_t counter = 0;

  while (1) {

    if (xQueueReceive(xQueue, &counter, portMAX_DELAY)) {
      printf("[Consumer Task]: received %d\n\r", counter);

      // simulate some operation
      vTaskDelay(2);
    }
  }
}

/*
 * Increment the SystemTick. If the increment unblocks a task, `xTaskIncrementTick` returns True.
 * The task can be scheduled using `portYIELD_FROM_ISR` (*_FROM_ISR procedures are ok to call within 
 * an ISR).
 *
 * https://rcc.freertos.org/Documentation/02-Kernel/05-RTOS-implementation-tutorial/02-Building-blocks/03-The-RTOS-tick
 */
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

/*
 * This function overrides the default application_interrupt_handler (defined as weak). This is invoked when EVERY
 * external trap arrives. This function polls the PLIC and increments the SystemTick when the timer is the source
 * interrupted.
 */
void freertos_risc_v_application_interrupt_handler(uint32_t mcause) {
  (void)mcause;

  uint32_t interrupt_id = plic_claim();

  switch (interrupt_id) {
  case 0x2:
    vExternalTickIncrement();
    break;
  default:
    break;
  }
  plic_complete(interrupt_id);
}

void vAssertCalled(const char *file, int line) {
  (void)file;
  (void)line;

  __asm("ebreak");
}

#ifdef configCHECK_FOR_STACK_OVERFLOW
/* Called if a task overflows its stack space */
void vApplicationStackOverflowHook(TaskHandle_t xTask, char *pcTaskName) {
  (void)xTask;
  (void)pcTaskName;

  __asm volatile("ebreak");
}
#endif // configCHECK_FOR_STACK_OVERFLOW

#ifdef configUSE_MALLOC_FAILED_HOOK
/* Called if pvPortMalloc() fails (heap exhausted) */
void vApplicationMallocFailedHook(void) {
  __asm volatile("ebreak");
}
#endif // configUSE_MALLOC_FAILED_HOOK

/*
 * Configure an external timer as the system timer. Enables the PLIC that configures the timer peripheral,
 * and enables the MEI (External interrupt) bit of the MIE register.
 */
void vPortSetupTimerInterrupt(void) {
  int ret;

  plic_init();
  plic_configure_set_one(1, 2);
  plic_enable_all();

  xlnx_tim_init(&timer);

  ret = xlnx_tim_configure(&timer);
  if (ret != UNINASOC_OK) {
    printf("Cannot configure timer\r\n");
    return;
  }

  ret = xlnx_tim_enable_int(&timer);
  if (ret != UNINASOC_OK) {
    printf("Cannot enable timer\r\n");
    return;
  }

  ret = xlnx_tim_start(&timer);
  if (ret != UNINASOC_OK) {
    printf("Cannot start timer\r\n");
    return;
  }

  // Enable local interrupts lines
  // MEI (External Interrupt)
  __asm volatile("csrs mie, %0" ::"r"(0x800));
}

int main() {

  uninasoc_init();

  printf("================= Simply-V Producer - Consumer with Timer ==================\n\r");

  xQueue = xQueueCreate(QUEUE_LENGTH, sizeof(uint32_t));
  configASSERT(xQueue != NULL);

  BaseType_t mem_1 =
      xTaskCreate(queueProducerTaskTimer, "ProducerTaskTimer", configMINIMAL_STACK_SIZE,
                  (void *)PRODUCER_PARAMETER, PRODUCER_TASK_PRIORITY, NULL);

  BaseType_t mem_2 = xTaskCreate(queueConsumerTaskTimer, "ConsumerTaskTimer", configMINIMAL_STACK_SIZE,
                                 (void *)0, CONSUMER_TASK_PRIORITY, NULL);

  configASSERT(mem_1 == pdPASS);

  configASSERT(mem_2 == pdPASS);

  size_t free_heap = xPortGetFreeHeapSize();

  configASSERT(free_heap > 0);
  vTaskStartScheduler();

  configASSERT(0); // insufficient RAM->scheduler task returns->vAssertCalled() called

  while (1);

  return 0;
}
