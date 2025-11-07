#include "uninasoc.h"
#include <stdint.h>

int main()
{
  // Local char buffer
  char str[128];

  // Initialize HAL
  uninasoc_init();

  // Spin indefinetly
  while(1){
    printf("Please enter a string\n\r");

    scanf("%s",str);

    printf("Your string is\n\r%s", str);
    printf("\n\r");
  }

  // Return to caller
  return 0;

}


