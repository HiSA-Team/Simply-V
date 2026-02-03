# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: Axilite to APB converter.
#              This module converts axilite to APB (for now, it is used for acessing APB interface of the HBM IP)

create_ip -name axi_apb_bridge -vendor xilinx.com -library ip -version 3.0 -module_name $::env(IP_NAME)
set_property -dict [list \
  CONFIG.C_ADDR_WIDTH {22} \
  CONFIG.C_APB_NUM_SLAVES {1} \
  CONFIG.C_BASEADDR {0x0000000000000000} \
  CONFIG.C_HIGHADDR {0x000000000FFFFFFF} \
  CONFIG.C_M_APB_PROTOCOL {apb3} \
] [get_ips $::env(IP_NAME)]