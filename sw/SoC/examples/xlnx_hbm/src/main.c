// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description:
//   Example demonstrating the use of the HBM IP.
//   The example performs basic load and store operations into the HBM.


#include "uninasoc.h"
#include <stdint.h>

#define HBM_BASE_ADDRESS 0x60000

int main()
{

    // Initialize HAL
    uninasoc_init();

    // Pointing to the HBM
    uint32_t * hbm = (uint32_t *) HBM_BASE_ADDRESS;

    printf("[HBM] Executing HBM test\n\r");

    uint32_t store_value = 0xDEADBEEF;

    printf("[HBM] Storing %d\n\r", store_value);
    *hbm = 0xDEADBEEF;

    uint32_t load_value = *hbm;
    printf("[HBM] Loading %d\n\n", load_value);

    // Return to caller
    return 0;

}


