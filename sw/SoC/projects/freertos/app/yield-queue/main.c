/*
 *  This examples shows basic Producer-Consumer communication with FreeRTOS queues.
 *  Producer sends an unsigned long counter value and the Consumer receives it (using a blocking operation).
 *  Tasks communicate with YIELD.
 *
 * Author: Giusppe Capasso <giuseppe.capasso17@studenti.unina.it>
 */

#include "FreeRTOS.h"
#include "queue.h"
#include "task.h"

#include "uninasoc.h"

#define mainQUEUE_PRODUCER_TASK_PRIORITY (tskIDLE_PRIORITY + 1)
#define mainQUEUE_CONSUMER_TASK_PRIORITY (tskIDLE_PRIORITY + 1)

#define mainQUEUE_LENGTH (1)

static QueueHandle_t xQueue = NULL;

static void queueProducerTaskYield(void *pvParameters) {

  (void)pvParameters;

  unsigned long counter = 0;
  size_t free_heap;

  while (1) {

    free_heap = xPortGetFreeHeapSize();
    configASSERT(free_heap > 0);

    printf("[Producer Task]: sending %ld...\n\r", counter);

    xQueueSend(xQueue, &counter, 0U);

    counter++;

    taskYIELD();
  }
}

static void queueConsumerTaskYield(void *pvParameters) {

  (void)pvParameters;

  size_t free_heap;
  unsigned long ulReceivedValue;

  while (1) {

    free_heap = xPortGetFreeHeapSize();
    configASSERT(free_heap > 0);

    if (xQueueReceive(xQueue, &ulReceivedValue, portMAX_DELAY)) {
      printf("[Consumer Task]: received %ld\n\r", ulReceivedValue);
    }

    taskYIELD();
  }
}

void vAssertCalled(const char *file, int line) {

  const char *f = file;
  int l = line;
  (void)f;
  (void)l;
  __asm("ebreak");
}

void vPortSetupTimerInterrupt(void) {
  // define if you need to set the timer interrupt,otherwise an empty definition
  // is still necessary to overwrite the weak definition in port.c and to avoid
  // unwanted jumps to reset handler
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

int main() {

  uninasoc_init();
  printf("================= Simply-V Producer - Consumer with Yield =================\n\r");

  xQueue = xQueueCreate(mainQUEUE_LENGTH, sizeof(unsigned long));
  configASSERT(xQueue != NULL);

  BaseType_t mem_1 =
      xTaskCreate(queueProducerTaskYield, "ProducerTaskYield", configMINIMAL_STACK_SIZE,
                  NULL, mainQUEUE_PRODUCER_TASK_PRIORITY, NULL);

  BaseType_t mem_2 = xTaskCreate(
      queueConsumerTaskYield, "ConsumerTaskYield", configMINIMAL_STACK_SIZE,
      NULL, mainQUEUE_CONSUMER_TASK_PRIORITY, NULL);

  configASSERT(mem_1 == pdPASS);

  configASSERT(mem_2 == pdPASS);

  size_t free_heap = xPortGetFreeHeapSize();

  configASSERT(free_heap > 0);

  vTaskStartScheduler();

  configASSERT(0); // insufficient RAM->scheduler task returns->vAssertCalled() called

  while (1);

  return 0;
}
