#include "simplyv.h"
#include <stdint.h>

// CMAC Base Address
#define CMAC_BASEADDR   ((uintptr_t)_peripheral_CMAC_CSR_start)
// AXIS FIFO register offsets in xlnx_cmac.h already include +0x10000.
#define AXIS_FIFO_BASEADDR   ((uintptr_t)_peripheral_CMAC_CSR_start)
// Axis FIFO Data Base Address
#define AXIS_FIFO_DATA_BASEADDR   ((uintptr_t)_peripheral_CMAC_DATA_start)

#define ETH_FRAME_BYTES        64u

int main()
{
  uint8_t rx_data[ETH_FRAME_BYTES];

  // Initialize HAL
  simplyv_init();

  // // Initialize the CMAC
  // printf("Initializing the CMAC...\n\r");
  // xlnx_cmac_init(CMAC_BASEADDR);

  // // Initialize the Axis FIFO
  // printf("Initializing the Axis FIFO...\n\r");
  // xlnx_axis_fifo_init(AXIS_FIFO_BASEADDR);

  printf("Waiting RX frames...\n\r");
  while (1) {
    size_t rx_size = xlnx_rx_axis_fifo_data(AXIS_FIFO_BASEADDR, AXIS_FIFO_DATA_BASEADDR, rx_data, sizeof(rx_data));
    if (rx_size == 0) {
      continue;
    }
    printf("RX (%lu bytes): ", (unsigned long)rx_size);
    for (size_t i = 0; i < rx_size; i++) {
      printf("%c", (char)rx_data[i]);
    }
    printf("\n\r");
  }

}


