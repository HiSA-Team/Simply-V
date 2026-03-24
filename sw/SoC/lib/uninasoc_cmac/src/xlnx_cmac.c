// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description:
//  This file implements all the CMAC subsystem's related functions


#include "xlnx_cmac.h"


void iowrite32 (uint32_t addr, uint32_t val)
{
  uint32_t * ptr = (uint32_t *) addr;
  *ptr = val;
}

uint32_t ioread32 (uint32_t addr)
{
  return *((uint32_t *) addr);
}


// TODO: here there are some conditions to check when writing...
void cmac_init (uint32_t baseaddr)
{
  iowrite32(baseaddr + CMAC_CSR_RSFEC_CONFIG_ENABLE, 0x3);
  iowrite32(baseaddr + CMAC_CSR_RSFEC_CONFIG_INDICATION_CORRECTION, 0x7);
  iowrite32(baseaddr + CMAC_CSR_CONFIGURATION_RX_REG1, 0x1);
  iowrite32(baseaddr + CMAC_CSR_CONFIGURATION_TX_REG1, 0x10);
  iowrite32(baseaddr + CMAC_CSR_CONFIGURATION_TX_REG1, 0x1);
}

// TODO: here there are some conditions to check when writing...
void axis_fifo_init (uint32_t baseaddr)
{
  ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  iowrite32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG, 0xFFFFFFFF);
  ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  ioread32(baseaddr + AXIS_FIFO_INTERRUPT_ENABLE_REG);
  ioread32(baseaddr + AXIS_FIFO_TX_VACANCY_REG);
  ioread32(baseaddr + AXIS_FIFO_RX_OCCUPANCY_REG);
}


uint8_t rx_axis_fifo_data (uint32_t baseaddr, uint32_t data_baseaddr)
{
  uint32_t isr = ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  if ((isr != 0x04000000)) return 0; // nothing received
  iowrite32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG, 0xFFFFFFFF);
  isr = ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  uint32_t rx_occupancy = ioread32(baseaddr + AXIS_FIFO_RX_OCCUPANCY_REG);
  uint32_t rx_len = ioread32(baseaddr + AXIS_FIFO_RX_LEN_REG);
  uint32_t rx_dest_addr = ioread32(baseaddr + AXIS_FIFO_RX_DST_ADDR_REG);
  rx_occupancy = ioread32(baseaddr + AXIS_FIFO_RX_OCCUPANCY_REG);
  uint32_t data = 0;
  if (rx_occupancy > 0) {
    data = ioread32(data_baseaddr + AXIS_FIFO_RX_DATA);

  }
  return 1;
}


void tx_axis_fifo_data (uint32_t baseaddr, uint32_t data_baseaddr, uint32_t data, uint32_t data_size)
{
  iowrite32(baseaddr + AXIS_FIFO_INTERRUPT_ENABLE_REG, 0x0C000000); // Enable transmit complete and receive complete interrupts, not needed in our case
  iowrite32(baseaddr + AXIS_FIFO_TX_DST_ADDR_REG, 0x00000002);      // This is 0x0 maybe
  iowrite32(data_baseaddr + AXIS_FIFO_TX_DATA, 0xFFFFFFFF);
  // for (uint32_t i=0; i<(data_size/4); i++){                              // Data size is in byte, we write 32 bits at time in the FIFO
    // iowrite32(data_baseaddr + AXIS_FIFO_TX_DATA, data);
  // }
  uint32_t tx_vacancy = ioread32(baseaddr + AXIS_FIFO_TX_VACANCY_REG);               // Read the transmit FIFO vacancy 0x000001F4
  iowrite32(baseaddr + AXIS_FIFO_TX_LEN_REG, /*data_size+*/4);                 // Transmit length (bytes), this starts transmission (+4 bytes as preamble)
  uint32_t isr = ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  while (isr == 0) {
    isr = ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  }
  iowrite32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG, 0xFFFFFFFF);
  isr = ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  while (isr != 0) {
    isr = ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  }
  tx_vacancy = ioread32(baseaddr + AXIS_FIFO_TX_VACANCY_REG);               // Read the transmit FIFO vacancy 0x000001F4
}
