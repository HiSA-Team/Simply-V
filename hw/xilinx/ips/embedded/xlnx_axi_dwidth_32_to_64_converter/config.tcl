# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: AXI Data Width Converter - Needed to link the XDMA (minimum 64 bits) to the AXI crossbar (32 bits)

create_ip -name axi_dwidth_converter -vendor xilinx.com -library ip -version 2.1 -module_name $::env(IP_NAME)

set_property -dict [list \
  CONFIG.MI_DATA_WIDTH {64} \
  CONFIG.SI_DATA_WIDTH {32} \
  CONFIG.SI_ID_WIDTH $::env(MBUS_ID_WIDTH) \
] [get_ips $::env(IP_NAME)]
