/*
 * This example shows a simple Task communication using Yield. Tasks have different priority and 
 * do not share anything. This just demonstrated the basic FreeRTOS scheduler functionalities.
 *
 * Author: Giusppe Capasso <giuseppe.capasso17@studenti.unina.it>
 */

#include "FreeRTOS.h"
#include "task.h"
#include "uninasoc.h"

#define BASIC_TASK1_YIELD_PRIORITY (tskIDLE_PRIORITY + 1)
#define BASIC_TASK2_YIELD_PRIORITY (tskIDLE_PRIORITY + 2)

#define BASIC_TASK1_YIELD_PARAMETER (1)
#define BASIC_TASK2_YIELD_PARAMETER (2)

static void basicTaskYield1(void *pvParameters) {

  uint32_t a;
  uint32_t b = 3;

  configASSERT(((uint32_t)pvParameters) == BASIC_TASK1_YIELD_PARAMETER);
  size_t free_heap;

  while (1) {
    free_heap = xPortGetFreeHeapSize();
    configASSERT(free_heap > 0);

    a = b + (uint32_t)pvParameters;
    (void)a;

    printf("Hello from task 1\n\r");

    taskYIELD();
  }
}

static void basicTaskYield2(void *pvParameters) {

  uint32_t a;
  uint32_t b = 3;

  configASSERT(((uint32_t)pvParameters) == BASIC_TASK2_YIELD_PARAMETER);
  size_t free_heap;

  while (1) {
    free_heap = xPortGetFreeHeapSize();
    configASSERT(free_heap > 0);

    a = b - (uint32_t)pvParameters;
    (void)a;

    printf("Hello from task 2\r\n");

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
  printf("================= SIMPLY-V Yield Example =================\n\r");

  // Create FreeRTOS Task
  BaseType_t mem_1 = xTaskCreate(basicTaskYield1, "t1", configMINIMAL_STACK_SIZE,
                                 (void *)BASIC_TASK1_YIELD_PARAMETER, BASIC_TASK1_YIELD_PRIORITY, NULL);

  BaseType_t mem_2 = xTaskCreate(basicTaskYield2, "t2", configMINIMAL_STACK_SIZE,
                                 (void *)BASIC_TASK2_YIELD_PARAMETER, BASIC_TASK2_YIELD_PRIORITY, NULL);

  configASSERT(mem_1 == pdPASS);

  configASSERT(mem_2 == pdPASS);

  size_t free_heap = xPortGetFreeHeapSize();

  configASSERT(free_heap > 0);
  vTaskStartScheduler();

  configASSERT(0); // insufficient RAM->scheduler task returns->vAssertCalled() called

  while (1);

  return 0;
}
