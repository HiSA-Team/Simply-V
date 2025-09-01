# Author: Manuel Maddaluno <manuel.maddaluno@unina.it>
# Description: CMAC configuration file

create_ip -name cmac_usplus -vendor xilinx.com -library ip -version 3.1 -module_name $::env(IP_NAME)

# TODO: For now the DIFFCLK_BOARD_INTERFACE and the ETHERNET_BOARD_INTERFACE are hardcoded. Need to be parametrized
set_property CONFIG.DIFFCLK_BOARD_INTERFACE qsfp0_156mhz [get_ips $::env(IP_NAME)]
set_property CONFIG.ETHERNET_BOARD_INTERFACE qsfp0_4x [get_ips $::env(IP_NAME)]

set_property -dict [list \
  CONFIG.CMAC_CAUI4_MODE {1} \
  CONFIG.CMAC_CORE_SELECT {CMACE4_X0Y8} \
  CONFIG.GT_GROUP_SELECT {X1Y44~X1Y47} \
  CONFIG.ENABLE_AXI_INTERFACE {1} \
  CONFIG.RX_MAX_PACKET_LEN {1518} \
  CONFIG.USER_INTERFACE {AXIS} \
  CONFIG.INCLUDE_RS_FEC {1} \
  CONFIG.GT_DRP_CLK {250} \
] [get_ips $::env(IP_NAME)]