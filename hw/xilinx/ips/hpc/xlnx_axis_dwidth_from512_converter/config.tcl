# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: AXI Stream Dwidth Converter (axis_dwidth_converter) IP configuration file
#              This IP is used for converting the AXI Stream data width from 512 bits to MBUS_DATA_WIDTH bits

create_ip -name axis_dwidth_converter -vendor xilinx.com -library ip -version 1.1 -module_name $::env(IP_NAME)
set_property -dict [list \
  CONFIG.HAS_TKEEP {1} \
  CONFIG.HAS_TLAST {1} \
  CONFIG.S_TDATA_NUM_BYTES {64} \
  CONFIG.TUSER_BITS_PER_BYTE {1} \
] [get_ips $::env(IP_NAME)]

set_property CONFIG.M_TDATA_NUM_BYTES [expr $::env(MBUS_DATA_WIDTH)/8] [get_ips $::env(IP_NAME)]
