// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description:
//   Example demonstrating the use of the HBM IP.
//   The example performs basic load and store operations into the HBM.


#include "uninasoc.h"
#include <stdint.h>

#define HBM_BASE_ADDRESS 0x60000
#define N_ACCESSES 100
#define STRIDE_ACCESS_WORD 4

int main()
{

    // Initialize HAL
    uninasoc_init();

    // Pointing to the HBM
    volatile uint32_t * hbm = (volatile uint32_t *) HBM_BASE_ADDRESS;

    printf("[HBM] Executing HBM test\n\r");

    uint32_t store_value = 0xDEADBEEF;
    uint32_t load_value = 0; 

    for (uint32_t i=0; i<N_ACCESSES; i++) {

	
        printf("[HBM] Storing 0x%x at 0x%x\n\r", store_value, hbm);
    
        *hbm = store_value;

        load_value = *hbm;
        printf("[HBM] Loading 0x%x at 0x%x\n\r", load_value, hbm);

	hbm += STRIDE_ACCESS_WORD;
        
	if (load_value != store_value) {
	    printf("[HBM] ERROR: stored 0x%x but loaded 0x%x\n\r", store_value, load_value);
	}
    }

    // Return to caller
    return 0;

}


