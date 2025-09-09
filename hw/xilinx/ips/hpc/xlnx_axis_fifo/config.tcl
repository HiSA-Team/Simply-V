# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: AXI Stream FIFO (axi_fifo_mm_s) IP configuration file
#              This IP is used for converting AXI Stream (from/to the CMAC) to AXI4 (from/to the core)

# Set base address this is modified by config-based script
set base_offset {0x80000}
set base_address [format 0x%X [expr $base_offset + 0x0]]

create_ip -name axi_fifo_mm_s -vendor xilinx.com -library ip -version 4.3 -module_name $::env(IP_NAME)

set_property -dict [list \
  CONFIG.C_DATA_INTERFACE_TYPE {1} \
  CONFIG.C_HAS_AXIS_TKEEP {true} \
  CONFIG.C_S_AXI4_DATA_WIDTH {512} \
  CONFIG.C_USE_TX_CTRL {0} \
  CONFIG.C_AXI4_BASEADDR $base_address \
] [get_ips $::env(IP_NAME)]