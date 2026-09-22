// Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
// Description:
//  This file implements all the CMAC subsystem's related functions


#include "xlnx_cmac.h"

#define AXIS_FIFO_ISR_RX_COMPLETE 0x04000000u
#define AXIS_FIFO_ISR_TX_COMPLETE 0x08000000u
#define AXIS_FIFO_ISR_ALL         0xFFFFFFFFu
#define AXIS_FIFO_POLL_TIMEOUT    1000000u
#define AXIS_FIFO_MIN_TX_BYTES    64u

static uint32_t xlnx_pack_u32(const uint8_t *bytes, size_t size)
{
  uint32_t value = 0;

  for (size_t i = 0; i < size; i++) {
    value |= ((uint32_t)bytes[i]) << (8u * (uint32_t)i);
  }

  return value;
}

static size_t xlnx_unpack_u32(uint32_t value, uint8_t *bytes, size_t max_size)
{
  size_t count = (max_size >= 4u) ? 4u : max_size;

  for (size_t i = 0; i < count; i++) {
    bytes[i] = (uint8_t)((value >> (8u * (uint32_t)i)) & 0xFFu);
  }

  return count;
}

void xlnx_cmac_init(uint32_t baseaddr)
{
  iowrite32(baseaddr + CMAC_CSR_RSFEC_CONFIG_ENABLE, 0x3);
  iowrite32(baseaddr + CMAC_CSR_RSFEC_CONFIG_INDICATION_CORRECTION, 0x7);
  iowrite32(baseaddr + CMAC_CSR_CONFIGURATION_RX_REG1, 0x1);
  iowrite32(baseaddr + CMAC_CSR_CONFIGURATION_TX_REG1, 0x10);
  iowrite32(baseaddr + CMAC_CSR_CONFIGURATION_TX_REG1, 0x1);
}

void xlnx_axis_fifo_init(uint32_t baseaddr)
{
  (void)ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  iowrite32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG, AXIS_FIFO_ISR_ALL);
  (void)ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  iowrite32(baseaddr + AXIS_FIFO_INTERRUPT_ENABLE_REG, AXIS_FIFO_ISR_TX_COMPLETE | AXIS_FIFO_ISR_RX_COMPLETE);
  (void)ioread32(baseaddr + AXIS_FIFO_INTERRUPT_ENABLE_REG);
  (void)ioread32(baseaddr + AXIS_FIFO_TX_VACANCY_REG);
  (void)ioread32(baseaddr + AXIS_FIFO_RX_OCCUPANCY_REG);
}


size_t xlnx_rx_axis_fifo_data(uint32_t baseaddr, uint32_t data_baseaddr, uint8_t *rx_buf, size_t rx_buf_size)
{

  if (rx_buf == 0 || rx_buf_size == 0u) {
    return 0u;
  }

  uint32_t isr = ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  if ((isr & AXIS_FIFO_ISR_RX_COMPLETE) == 0u) {
    return 0u;
  }

  iowrite32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG, AXIS_FIFO_ISR_ALL);
  (void)ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);

  uint32_t rx_occupancy = ioread32(baseaddr + AXIS_FIFO_RX_OCCUPANCY_REG);
  uint32_t rx_len = ioread32(baseaddr + AXIS_FIFO_RX_LEN_REG);
  
  if (rx_occupancy == 0u || rx_len == 0u) {
    return 0u;
  }

  (void)ioread32(baseaddr + AXIS_FIFO_RX_DST_ADDR_REG);
  (void)ioread32(baseaddr + AXIS_FIFO_RX_OCCUPANCY_REG);


  size_t bytes_to_copy = (size_t)rx_len;
  if (bytes_to_copy > rx_buf_size) {
    bytes_to_copy = rx_buf_size;
  }

  size_t words_to_read = (bytes_to_copy + 3u) / 4u;
  size_t bytes_written = 0u;

  for (size_t i = 0; i < words_to_read; i++) {
    uint32_t data = ioread32(data_baseaddr + AXIS_FIFO_RX_DATA);
    size_t remaining = bytes_to_copy - bytes_written;
    size_t chunk = (remaining >= 4u) ? 4u : remaining;
    bytes_written += xlnx_unpack_u32(data, &rx_buf[bytes_written], chunk);
  }

  return bytes_written;
}


size_t xlnx_tx_axis_fifo_data(uint32_t baseaddr, uint32_t data_baseaddr, const uint8_t *tx_buf, size_t tx_buf_size)
{
  if (tx_buf == 0) {
    return 0u;
  }

  if (tx_buf_size < AXIS_FIFO_MIN_TX_BYTES) {
    return 0u;
  }

  iowrite32(baseaddr + AXIS_FIFO_INTERRUPT_ENABLE_REG, AXIS_FIFO_ISR_TX_COMPLETE | AXIS_FIFO_ISR_RX_COMPLETE);
  iowrite32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG, AXIS_FIFO_ISR_ALL);
  iowrite32(baseaddr + AXIS_FIFO_TX_DST_ADDR_REG, 0x00000002u);

  size_t words_to_write = (tx_buf_size + 3u) / 4u;
  size_t bytes_consumed = 0u;

  for (size_t i = 0; i < words_to_write; i++) {
    size_t remaining = tx_buf_size - bytes_consumed;
    size_t chunk = (remaining >= 4u) ? 4u : remaining;
    uint32_t data = xlnx_pack_u32(&tx_buf[bytes_consumed], chunk);
    iowrite32(data_baseaddr + AXIS_FIFO_TX_DATA, data);
    bytes_consumed += chunk;
  }

  (void)ioread32(baseaddr + AXIS_FIFO_TX_VACANCY_REG);
  iowrite32(baseaddr + AXIS_FIFO_TX_LEN_REG, (uint32_t)tx_buf_size);

  uint32_t isr = ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  uint32_t timeout = AXIS_FIFO_POLL_TIMEOUT;
  while (((isr & AXIS_FIFO_ISR_TX_COMPLETE) == 0u) && (timeout > 0u)) {
    isr = ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
    timeout--;
  }

  if ((isr & AXIS_FIFO_ISR_TX_COMPLETE) == 0u) {
    return 0u;
  }

  iowrite32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG, AXIS_FIFO_ISR_ALL);
  (void)ioread32(baseaddr + AXIS_FIFO_INTERRUPT_STATUS_REG);
  (void)ioread32(baseaddr + AXIS_FIFO_TX_VACANCY_REG);

  return tx_buf_size;
}
