#include "uninasoc.h"
#include <stdint.h>

int main()
{

  // Initialize HAL
  uninasoc_init();

  // Print
  printf("Hello World from CORE 0 !\n\r");

  // Return to caller
  return 0;

}

