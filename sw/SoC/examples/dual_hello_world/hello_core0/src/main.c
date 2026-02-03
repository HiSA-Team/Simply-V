#include "simplyv.h"
#include <stdint.h>

int main()
{

  // Initialize HAL
  simplyv_init();

  // Print
  printf("Hello World from CORE 0 !\n\r");

  // Return to caller
  return 0;

}

