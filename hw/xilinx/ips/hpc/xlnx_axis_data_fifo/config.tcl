# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: AXI Stream data FIFO IP configuration file
#              This IP is used for buffering data from the CMAC to the match-engine

create_ip -name axis_data_fifo -vendor xilinx.com -library ip -version 2.0 -module_name $::env(IP_NAME)
set_property -dict [list \
  CONFIG.FIFO_DEPTH {16} \
  CONFIG.FIFO_MEMORY_TYPE {auto} \
  CONFIG.HAS_TKEEP {1} \
  CONFIG.HAS_TLAST {1} \
  CONFIG.TUSER_WIDTH {1} \
  CONFIG.IS_ACLK_ASYNC {0} \
  CONFIG.TDATA_NUM_BYTES {64} \
] [get_ips $::env(IP_NAME)]