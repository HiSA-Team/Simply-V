#include "tinyIO.h"
#include <stdint.h>

extern const volatile uint32_t _peripheral_UART_start;
extern const volatile uint32_t _peripheral_CMAC_CSR_start;
extern const volatile uint32_t _peripheral_m_acc_start;

// CMAC CSR offsets
#define CMAC_CSR_RSFEC_CONFIG_ENABLE                 0x0000107C
#define CMAC_CSR_RSFEC_CONFIG_INDICATION_CORRECTION  0x00001000
#define CMAC_CSR_CONFIGURATION_RX_REG1               0x00000014
#define CMAC_CSR_CONFIGURATION_TX_REG1               0x0000000C

// AXI-Stream FIFO CSR offsets
#define AXIS_FIFO_INTERRUPT_STATUS_REG               (0x00010000 + 0x0)
#define AXIS_FIFO_INTERRUPT_ENABLE_REG               (0x00010000 + 0x4)
#define AXIS_FIFO_TX_VACANCY_REG                     (0x00010000 + 0xC)
#define AXIS_FIFO_RX_OCCUPANCY_REG                   (0x00010000 + 0x1C)
#define AXIS_FIFO_RX_LEN_REG                         (0x00010000 + 0x24)
#define AXIS_FIFO_RX_DST_ADDR_REG                    (0x00010000 + 0x30)
#define AXIS_FIFO_TX_DATA                            (0x0)
#define AXIS_FIFO_RX_DATA                            (0x1000)


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

void rx_axis_fifo_data (uint32_t baseaddr, uint32_t data_baseaddr)
{
  uint32_t isr = ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  printf("ISR: %d\n\r", isr);

  iowrite32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG, 0xFFFFFFFF);

  isr = ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  printf("ISR: %d\n\r", isr);

  uint32_t rx_occupancy = ioread32(baseaddr + AXIS_FIFO_RX_OCCUPANCY_REG);
  printf("RX OCC: %d\n\r", rx_occupancy);

  uint32_t rx_len = ioread32(baseaddr + AXIS_FIFO_RX_LEN_REG);
  printf("RX LEN: %d\n\r", rx_len);

  uint32_t rx_dest_addr = ioread32(baseaddr + AXIS_FIFO_RX_DST_ADDR_REG);
  printf("RX DEST: %d\n\r", rx_dest_addr);

  rx_occupancy = ioread32(baseaddr + AXIS_FIFO_RX_OCCUPANCY_REG);
  printf("RX OCC: %d\n\r", rx_occupancy);

  uint32_t data = 0;
  if (rx_occupancy > 0) {
    data = ioread32(data_baseaddr + AXIS_FIFO_RX_DATA);
    printf("DATA: %d\n\r", data);
  }

}


int main()
{

  uint32_t uart_base_address = (uint32_t) &_peripheral_UART_start;
  uint32_t cmac_csr_base_address = (uint32_t) &_peripheral_CMAC_CSR_start;
  uint32_t axis_fifo_data_base_address = (uint32_t) &_peripheral_m_acc_start;

  tinyIO_init(uart_base_address);

  printf("Trying to init the CMAC...\n\r");

  cmac_init(cmac_csr_base_address);
  axis_fifo_init(cmac_csr_base_address);

  rx_axis_fifo_data(cmac_csr_base_address, axis_fifo_data_base_address);



  while(1);

  return 0;

}


